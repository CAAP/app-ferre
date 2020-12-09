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
local TOK	  = os.getenv'TOK_TCP'
local TIK	  = os.getenv'TIK_TCP'

local TOKK	  = "Gl-wH9L/rnwK8?V2-+pu@(V!aBYXMY.Y]M!/y2M-"
local TIKK	  = "!bgA6xLy8v/sjSHhTo1uO{6jO/bUE&ELh:pRr:K!"

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

