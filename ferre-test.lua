#! /usr/bin/env lua53

-- Import Section
--
local context	  = require'lzmq'.context

local assert	  = assert
local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc'

--------------------------------
-- Local function definitions --
--------------------------------
--

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local ear = assert(CTX:socket'SUB')

assert(ear:connect( DOWNSTREAM ))

assert(ear:subscribe'')

while true do print(ear:recv_msg(), '\n') end

