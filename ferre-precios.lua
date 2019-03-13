#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local dbconn	  = require'carlos.ferre'.dbconn
local asJSON	  = require'carlos.json'.asJSON
local connect 	  = require'carlos.sqlite'.connect
local file_exists = require'carlos.bsd'.file_exists
local socket	  = require'carlos.zmq'.socket

local open	  = io.open
local env	  = os.getenv
local concat	  = table.concat
local assert	  = assert

local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

--------------------------------
-- Local function definitions --
--------------------------------
--

---------------------------------
-- Program execution statement --
---------------------------------
--

