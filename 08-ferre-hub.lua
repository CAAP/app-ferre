#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local receive	  = require'carlos.ferre'.receive
local context	  = require'lzmq'.context
local proxy	  = require'lzmq'.proxy
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

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local PEER	  = "tcp://*:5630"
local VULTR	  = "tcp://*:5610"

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

local stream = assert(CTX:socket'XSUB')

assert( stream:linger(0) )

--assert( stream:set_id('peer') )

assert( stream:bind( PEER ) )

print('\nSuccessfully bound to:', PEER, '\n')

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'XPUB')

assert( msgr:linger(0) )

--assert( msgr:set_id(TIENDA) )

--assert( keypair():client(msgr, SRVK) )

assert( msgr:bind( VULTR ) )

print('\nSuccessfully bound to', VULTR, '\n')

--
-- -- -- -- -- --
--

local logA = assert(CTX:socket'PAIR')

assert( logA:linger(0) )

assert( logA:bind'inproc://log' )

--
-- -- -- -- -- --
--

local logB = assert(CTX:socket'PAIR')

assert( logB:linger(0) )

assert( logB:connect'inproc://log' )

--
-- -- -- -- -- --
--

proxy(stream, msgr, logA)

while true do
print'+\n'

    pollin{logB}

    if logB:events() == 'POLLIN' then

	local msg = logB:recv_msgs()

	print('LOG:', concat(msg, ' '), '\n')

    end
end
