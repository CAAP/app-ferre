-- Import Section
--
local socket  = require'carlos.zmq'.socket
local format  = require'string'.format
local sleep     = require'lbsd'.sleep

local rand = math.random

local assert = assert
local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPDATES   = 'ipc://updates.ipc'
local TICKETS   = 'ipc://tickets.ipc'
local TIMEOUT   = 5000 -- 5 secs
local SUBS	= {'vers', 'tkts'}
local VERS      = {} -- week, vers

--------------------------------
-- Local function definitions --
--------------------------------
--
local function sse( event, data )
    return format('%s event: %q\ndata: %s\n\n\n', event, event, data)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
local pub = socket'PUB'

assert( pub.bind(TICKETS) )

while true do
    local msg = sse('vers', rand(200,500))
    print( msg )
    pub.send( msg )
    sleep(3) -- 1 s
end

