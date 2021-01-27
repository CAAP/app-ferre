#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'

local concat	  = table.concat
local assert	  = assert
local exit	  = os.exit
local print	  = print

local WSS	  = os.getenv'WEBSOCKET_IP'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

local ops = MGR.ops

--------------------------------
-- Local function definitions --
--------------------------------
--

local function switch( c, msg, code )

    print('Message received:', msg, '\n')

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

local function wsfn(c, ev, ...)
    if ev == ops.OPEN then
	print('Connection established to peer:', c:ip(), '\n')
	c:send()

    elseif ev == ops.WS then
	switch( c, ... )

    elseif ev == ops.ERROR then
	print('ERROR:', ...)
	c:close()
--[[
-- XXX TAKE CARE, SO ONE CAN RETRY CONNECTION AUTOMAGICALLY XXX
-- 	MAKING USE OF TIMERS
--]]
    elseif ev == ops.CLOSE then
	print('Connection closed\n')
	MGR.timer(3000, function() MGR.connect(WSS, wsfn, ops.websocket|ops.ssl|ops.ca) end)

    end
end

assert( MGR.connect(WSS, wsfn, ops.websocket|ops.ssl|ops.ca) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

