#! /usr/bin/env lua53

-- Import Section
--
local tabs	  = require'carlos.ferre.tabs'
local asUUID	  = require'carlos.ferre.uuids'
local reduce	  = require'carlos.fold'.reduce
local receive	  = require'carlos.ferre'.receive
local deserialize = require'carlos.ferre'.deserialize
local serialize   = require'carlos.ferre'.serialize
local socket	  = require'lzmq'.socket
local pollin	  = require'lzmq'.pollin
local zmq_opt	  = require'lzmq'.opt

local rconnect	  = require'redis'.connect
local posix	  = require'posix.signal'

local assert	  = assert
local exit	  = os.exit
local concat	  = table.concat
local insert	  = table.insert
local remove	  = table.remove
local format	  = string.format
local print	  = print
local type	  = type

local STREAM	  = os.getenv'STREAM_IPC'
local REDIS	  = os.getenv'REDISC'

-- No more external access after this point
_ENV = nil -- or M

assert(zmq_opt('sockets', 30)) -- set the maximum number of active socket connections

-- Local Variables for module-only access
--

local client	  = assert( rconnect(REDIS, '6379') )

--------------------------------
-- Local function definitions --
--------------------------------
--

local function takeTwo(msg) return msg[1], msg[2] end

local function broadcast(skt, tb)
    if tb then
	reduce(tb, function(s) skt:send_msgs{'SSE', s} end)
	print( 'Broadcasting', #tb, 'message(s)\n\n' )
    end
end

local function toinmem(skt, msg)
    local cmd, s = takeTwo(msg)
    skt:send_msgs{'inmem', cmd, s}
end

local function todb(skt, msg)
    local cmd, s = takeTwo(msg)
    skt:send_msgs{'DB', cmd, s}
end

local function tabs2all(skt, msg)
    local cmd, s = takeTwo(msg)
    broadcast(skt, tabs(cmd, s))
end

local function uuid2db(skt, msg)
    local cmd, s = takeTwo(msg)
    local uuid, uid, pid = asUUID(client, s)
    if uuid then skt:send_msgs{'DB', cmd, serialize{uuid=uuid, uid=uid, pid=pid}} end
end

local function handover(skt, msg)
    remove(msg, 1) -- cmd i.e. 'reroute'
    skt:send_msgs( msg )
end

local function donothing()
end

---------------------------------
-- Program execution statement --
---------------------------------

local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
-- Initilize server(s)
--

local stream = assert(socket'ROUTER')

assert( stream:opt('mandatory', true) ) -- causes error in case of unroutable peer

assert( stream:bind( STREAM ) )

print('\nSuccessfully bound to:', STREAM, '\n')

--
-- -- -- -- -- --
--

local router = { query=toinmem,  rfc=toinmem,      bixolon=toinmem, 	uid=toinmem,
		 feed=toinmem,   ledger=toinmem,   adjust=toinmem,
		 update=todb,	 faltate=todb,	   eliminar=todb,
	 	 ticket=uuid2db, facturar=uuid2db, presupuesto=uuid2db,
	 	 msgs=tabs2all,  login=tabs2all,   delete=tabs2all,	tabs=tabs2all,
	 	 reroute=handover, pins=donothing }

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream}

    local events = stream:opt'events'

    if events.pollin then
	-- two messages received: cmd & [binser] Lua Object --
	local id, msg = receive( stream )
	local cmd = msg[1]

	print(id, concat(msg, ' '), '\n')

	if cmd == 'OK' then
	else router[cmd](stream, msg) end

    end

end

