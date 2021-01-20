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

local evs = MGR.events
local ops = MGR.ops

--------------------------------
-- Local function definitions --
--------------------------------
--

local function switch( c, msg, code )
    local k = 0

    print('Message received:', msg, '\n')

    if msg == 'peers' then
	local a = fd.reduce(fd.wrap(MGR.peers), fd.map(function(peer) return peer:ip() end), fd.into, {})
	c:send(concat(a, '\t'), ops.TEXT)
	k = 1

    else
	for peer in MGR.peers() do
	    peer:send(msg, code)
	    k = k + 1
	end

    end

    print('Message broadcasted to', k, 'peer(s)\n')

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
    if ev == evs.ACCEPT then
	print('Peer has connected:', c:ip(), '\n')

    elseif ev == evs.WS then
	switch( c, ... )

    elseif ev == evs.ERROR then
	print('ERROR:', ...)
	c:close()

    elseif ev == evs.CLOSE then
	print('Connection to', c:ip(), 'closed\n')

    end
end

local ws = assert( MGR.bind(WSS, wsfn, evs.WS) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

