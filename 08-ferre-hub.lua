#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'

local fd	  = require'carlos.fold'

local concat	  = table.concat
local assert	  = assert
local exit	  = os.exit
local print	  = print

local WSS	  = os.getenv'HUB_IP'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

local ops = MGR.ops

--------------------------------
-- Local function definitions --
--------------------------------
--
local function isvalid(peer)
    return peer:opt'accepted' and peer:opt'websocket'
end

local function switch( c, msg, code )
    local k = 0

    print('Message received:', msg, '\n')

    if msg == 'peers' then
	local a = fd.reduce(MGR.peers, fd.filter(isvalid), fd.map(function(p) return p:ip() end) fd.into, {})
	c:send(concat(a, '\t'), ops.TEXT)
	k = 1

    else
	fd.reduce(MGR.peers, function(p) if isvalid(p) then p:send(msg, code); k = k + 1 end end)

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
    if ev == ops.ACCEPT then
	print('Peer has connected:', c:ip(), '\n')

    elseif ev == ops.WS then
	switch( c, ... )

    elseif ev == ops.ERROR then
	print('ERROR:', ...)
	c:opt('closing', true)

    elseif ev == ops.CLOSE then
	print('Connection to', c:ip(), 'closed\n')

    end
end

assert( MGR.bind(WSS, wsfn, ops.websocket|ops.ssl|ops.cert|ops.key) )

local function keepalive()
    fd.reduce(MGR.peers, function(p) if isvalid(p) then p:send'Hi' end end)
end

local t1 = assert( MGR.timer(120000, keepalive, true) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

