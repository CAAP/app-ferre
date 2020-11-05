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

local VULTR	  = "tcp://192.168.1.110:5630" -- os.getenv'VULTR'

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
    local cmd = msg[2]
    if cmd == 'ticket' then
	local k = 'queue:tickets:'..msg[3]
	local ret = client:lrange(k, 0, -1)
	insert(ret, 1, 'ticketx') -- ADD uid |¬ msg[3]  XXX
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
--
local CTX = context()

local stream = assert(CTX:socket'DEALER')

assert( stream:immediate(true) )

assert( stream:linger(0) )

assert( msgr:set_id('vultr') )

assert( stream:bind( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

stream:send_msg'OK'

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

	local msg = stream:recv_msgs()
	local cmd = msg[1]:match'%a+'

	print('stream:\t', concat(msg, ' '), '\n')

	if cmd == 'OK' then

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

