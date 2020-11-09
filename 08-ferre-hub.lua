#! /usr/bin/env lua53

-- Import Section
--
local context	  = require'lzmq'.context
local proxy	  = require'lzmq'.proxy
local keypair	  = require'lzmq'.keypair

local rconnect	  = require'redis'.connect
local posix	  = require'posix.signal'

local assert	  = assert
local exit	  = os.exit
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'
local TIENDA	  = os.getenv'TIENDA'
local REDIS	  = os.getenv'REDISC'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local TIK	  = "tcp://*:5610"
local TOK	  = "tcp://*:5620"

local client	  = assert( rconnect(REDIS, '6379') )

local SRVKI	  = "/*FTjQVb^Hgww&{X*)@m-&D}7Lxk?f5o7mIe=![2"
local SRVKO	  = "/*FTjQVb^Hgww&{X*)@m-&D}7Lxk?f5o7mIe=![2"

--------------------------------
-- Local function definitions --
--------------------------------
--

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

local msgs = assert(CTX:socket'XSUB')

assert( msgs:linger(0) )

--assert( keypair():client(msgr, SRVKO) )

assert( msgs:bind( TOK ) )

print('\nSuccessfully bound to:', TOK, '\n')

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'XPUB')

assert( msgr:linger(0) )

--assert( keypair():client(msgr, SRVKI) )

assert( msgr:bind( TIK ) )

print('\nSuccessfully bound to', TIK, '\n')

--
-- -- -- -- -- --
--

proxy(msgs, msgr)

