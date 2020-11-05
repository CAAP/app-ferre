#! /usr/bin/env lua53

-- Import Section
--
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

local STREAM	  = os.getenv'STREAM_IPC'
local TIENDA	  = os.getenv'TIENDA'
local REDIS	  = os.getenv'REDISC'
local PEER	  = os.getenv'PEER'

local VULTR	  = "tcp://192.168.2.56:5630" -- os.getenv'VULTR'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	  = assert( rconnect(REDIS, '6379') )

local SRVK	  = "/*FTjQVb^Hgww&{X*)@m-&D}7Lxk?f5o7mIe=![2"

--------------------------------
-- Local function definitions --
--------------------------------
--

local function switch(msg)
    local cmd = msg[1]
    if cmd == 'ticketx' then
	local uid = msg[2]
	local k = 'queue:tickets:'..uid
	fd.reduce(client:lrange(k, 0, -1), fd.into, msg)
	return true

    elseif cmd == 'updatex' then
	return true

    else
	return false

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
--
local CTX = context()

local stream = assert(CTX:socket'DEALER')

assert( stream:immediate(true) )

assert( stream:linger(0) )

assert( stream:set_id('peer') )

assert( stream:bind( PEER ) )

print('\nSuccessfully bound to:', PEER, '\n')

stream:send_msg'OK'

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'DEALER')

assert( msgr:immediate(true) )

assert( msgr:linger(0) )

assert( msgr:set_id(TIENDA) )

--assert( keypair():client(msgr, SRVK) )

assert( msgr:connect( VULTR ) )

print('\nSuccessfully connected to', VULTR, '\n')

--msgr:send_msg'OK'

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream, msgr}

    if stream:events() == 'POLLIN' then

	local msg = stream:recv_msgs()

	print('stream:', concat(msg, ' '), '\n')

	if switch(msg) then
	    msgr:send_msgs( msg )
	end


    elseif msgr:events() == 'POLLIN' then

	local msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print('\nVULTR:', concat(msg, ' '), '\n')

	if cmd == 'OK' then

--	elseif cmd == 'updatex' then
--	    insert(msg, 1, 'DB')
--	    stream:send_msgs( msg )

	end

    end

end

