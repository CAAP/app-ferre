#! /usr/bin/env lua53

-- Import Section
--
local context	  = require'lzmq'.context

local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM = 'ipc://upstream.ipc'

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

ear:subscribe''


