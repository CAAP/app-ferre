-- Import Section
--
local socket  = require'carlos.zmq'.socket
local format  = require'string'.format

local assert = assert
local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT  = 'ipc://tickets.ipc'
local TIMEOUT   = 5000 -- 5 secs
local SUBS	= {'vers', 'tkts'}
local VERS = {} -- week, vers

--------------------------------
-- Local function definitions --
--------------------------------
--
local function sse( event, data )
    return format('event: %q\ndata: [\n%s\ndata: ]\n\n\n', event, data)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
local


