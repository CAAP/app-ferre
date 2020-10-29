#! /usr/bin/env lua53

-- Import Section
--
local tabs	  = require'carlos.ferre.tabs'
local asUUID	  = require'carlos.ferre.uuids'
local reduce	  = require'carlos.fold'.reduce
local receive	  = require'carlos.ferre'.receive
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local keypair	  = require'lzmq'.keypair

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
local TIENDA	  = os.getenv'TIENDA'

local VULTR	  = "tcp://192.168.1.110:5630" -- os.getenv'VULTR'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local TABS	  = { tabs=true, delete=true,
		      msgs=true, login=true }

local INMEM	  = { query=true, rfc=true, bixolon=true,
		      uid=true,     feed=true,
		      ledger=true,  adjust=true }

local FERRE 	  = { update=true, faltante=true, eliminar=true }

local client	  = assert( rconnect('127.0.0.1', '6379') )

local SRVK	  = "/*FTjQVb^Hgww&{X*)@m-&D}7Lxk?f5o7mIe=![2"

--------------------------------
-- Local function definitions --
--------------------------------
--

local function sendAll(skt, tag, msg)
    insert(msg, 1, tag)
    print( 'Sent to', tag, skt:send_msgs(msg), '\n' )
end

local function broadcast(skt, msg)
    local msg = msg or ': OK\n\n'
    local N = 1
    if type(msg) == 'table' then
	reduce(msg, function(m) skt:send_msgs{'SSE', m} end)
	N = #msg
    else
	skt:send_msgs{'SSE', msg}
    end
    print( 'Broadcasting', N, 'message(s)\n\n+\n' )
end

local function switch(msg)
    local cmd = msg[2]
    if cmd == 'ticket' then
	local k = 'queue:tickets:'..msg[3]
	local ret = client:lrange(k, 0, -1)
	insert(ret, 1, 'ticketx') -- ADD uid |� msg[3]  XXX
	return ret

    elseif cmd == 'updatex' then
	remove(msg, 1)
	return msg

    end
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
local CTX = context()

local stream = assert(CTX:socket'ROUTER')

assert( stream:mandatory(true) ) -- causes error in case of unroutable peer

assert( stream:bind( STREAM ) )

print('\nSuccessfully bound to:', STREAM, '\n')
--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'DEALER')

assert( msgr:immediate(true) )

assert( msgr:linger(0) )

assert( msgr:set_id(TIENDA) )

assert( keypair():client(msgr, SRVK) )

assert( msgr:connect( VULTR ) )

print('\nSuccessfully connected to', VULTR, '\n')

msgr:send_msg'OK'

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream, msgr}

    if stream:events() == 'POLLIN' then

	local id, msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print(id, concat(msg, ' '), '\n')

	if cmd == 'OK' then

	elseif cmd == 'SSE' then
	    stream:send_msgs( msg )

	elseif cmd == 'inmem' then
	    stream:send_msgs( msg )

	elseif cmd == 'vultr' then
	    msgr:send_msgs( switch( msg ) )
	    print'\nVULTR: Message sent for cloud storage\n'

	----------------------
	-- divide & conquer --
	----------------------
	elseif TABS[cmd]  then
	    broadcast( stream, tabs(cmd, msg) )

	elseif INMEM[cmd] then
	    insert(msg, 1, 'inmem')
	    stream:send_msgs(msg)

	elseif FERRE[cmd] then
	    insert(msg, 1, 'DB')
	    stream:send_msgs(msg)

	----------------------------------
	-- convert into MULTI-part msgs --
	----------------------------------
	elseif msg[2]:match'query=' then -- XXX ISTKT???
	    local uuid = asUUID(client, cmd, msg[2])
	    if uuid then stream:send_msgs{'DB', cmd, uuid} end

	end

    elseif msgr:events() == 'POLLIN' then

	local id, msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print('\nVULTR:', concat(msg, ' '), '\n')

	if cmd == 'OK' then

	elseif cmd == 'updatex' then
	    insert(msg, 1, 'DB')
	    stream:send_msgs( msg )

	end

    end

end

