-- Import Section
--
local fd	  = require'carlos.fold'

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

--[[
local reqs = assert(CTX:socket'PUSH')

assert(reqs:connect( DOWNSTREAM ))

print('Successfully connected to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--]]

