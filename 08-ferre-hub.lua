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

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local TOK	  = "tcp://*:5630"
local TIK	  = "tcp://*:5633"

local TIKK	  = "h#^6GEumy(oAlfY2:N9mf6%PxZ4.?OKNbq??EekL"
local TOKK	  = "Pp(1a]-goaKbWJJ@P][zqfifI5NA#/R*MMlK9!3!"

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

assert( msgs:curve( TOKK ) )

assert( msgs:bind( TOK ) )

print('\nSuccessfully bound to:', TOK, '\n')

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'XPUB')

assert( msgr:linger(0) )

assert( msgr:curve( TIKK ) )

assert( msgr:bind( TIK ) )

print('\nSuccessfully bound to', TIK, '\n')

--
-- -- -- -- -- --
--

proxy(msgs, msgr)

