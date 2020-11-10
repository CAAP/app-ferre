#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local into	  = require'carlos.fold'.into
local drop	  = require'carlos.fold'.drop
local receive	  = require'carlos.ferre'.receive
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local keypair	  = require'lzmq'.keypair
local b64	  = require'lints'.fromB64
local dN	  = require'binser'.dN

local rconnect	  = require'redis'.connect
local posix	  = require'posix.signal'

local assert	  = assert
local exit	  = os.exit
local concat	  = table.concat
local insert	  = table.insert
local remove	  = table.remove
local unpack	  = table.unpack
local format	  = string.format
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'
local REDIS	  = os.getenv'REDISC'
local TIENDA	  = os.getenv'TIENDA'
local TIK	  = os.getenv'TIK_TCP'
local TOK	  = os.getenv'TOK_TCP'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	  = assert( rconnect(REDIS, '6379') )

local SRVK	  = "/*FTjQVb^Hgww&{X*)@m-&D}7Lxk?f5o7mIe=![2"

local QTKT	  = 'queue:tickets:'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function deserialize(s)
    local a,i = dN(b64(s), 1)
    return a
end

local function switch(msg)
    local cmd = msg[1]
    if cmd == 'ticketx' then
	local uid = msg[2]
	local k = QTKT..uid
	reduce(client:lrange(k, 0, -1), into, msg)
	return true

    elseif cmd == 'updatex' then
	return true

    else
	return false

    end
end

local function process(msg)
    local cmd = msg[1]

    if cmd == TIENDA and #msg > 4 then cmd = 'updatex' end

    if cmd == 'ticketx' then
	local uid = msg[2]
	local k = QTKT..uid
	local data = drop(2, msg, into, {})
	client:rpush(k, unpack(data))
	return {'DB', cmd, uid}

    elseif cmd == 'updatex' then
-- DELAY XXX
	local vers = msg[3]
	local overs = msg[4]
	local v = client:get'app:updates:version'
	if overs == v then
	    local clave = msg[2]
	    local Q = msg[#msg]
	    local qs = deserialize( Q:match"'%([^']+)'%)$" )
	    local k = 'queue:uuids:'..clave
	    client:rpush(k, unpack(qs))
	    return {'DB', cmd, clave, vers}

	elseif vers == v then return 'OK'

	else return {'peer', TIENDA, v}

	end

    elseif cmd:match'FA-BJ' then
	local vers = msg[2]
	local v

	if vers == v then return 'OK'

	else return {'', , msg[2]} end

    else return 'OK' end

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
local CTX = context()

local stream = assert(CTX:socket'DEALER')

assert( stream:immediate(true) )

assert( stream:linger(0) )

assert( stream:set_id('peer') )

assert( stream:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

stream:send_msg'OK'

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUB')

assert( msgr:linger(0) )

assert( msgr:connect( TOK ) )

print('\nSuccessfully connected to', TOK, '\n')

--
-- -- -- -- -- --
--

local msgs = assert(CTX:socket'SUB')

assert( msgs:linger(0) )

assert( msgs:subscribe'updatex' )

assert( msgs:subscribe( TIENDA ) )

assert( msgs:connect( TIK ) )

print('\nSuccessfully connected to', TIK, '\n')

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream, msgs}

    if stream:events() == 'POLLIN' then

	local msg = stream:recv_msgs()

	print('stream:', concat(msg, ' '), '\n')

	if switch(msg) then
	    msgr:send_msgs( msg )
	end


    elseif msgs:events() == 'POLLIN' then

	local msg = msgr:recv_msgs()

	print('\nTIK:', concat(msg, ' '), '\n')

	stream:send_msgs( process(msg) )

    end

end

