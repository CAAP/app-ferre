#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'

local fd	  = require'carlos.fold'
local deserialize = require'carlos.ferre'.deserialize
local wse	  = require'carlos.ferre.wse'

local concat	  = table.concat
local assert	  = assert
local exit	  = os.exit
local print	  = print

local WSS	  = os.getenv'HUB_IP'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

local ops 	= MGR.ops

local PEERS 	= {} -- label, conn

--------------------------------
-- Local function definitions --
--------------------------------
--

local function isvalid( c ) return c:opt'accepted' and c:opt'websocket' end

local function switch( c, msg, code )
    local k = 0

    print('Message received:', msg, '\n')

    if msg == 'peers' then
	local a = fd.reduce(fd.keys(PEERS), fd.map(function(_,label) return label end), fd.into, {})
	c:send(concat(a, '\t'), ops.TEXT)
	k = 1

--    elseif msg:match'vers' then

--    elseif msg:match'%' then

    else
	fd.reduce(PEERS, function(peer) peer:send(msg, code); k = k + 1 end)

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
	print('\nNew connection established\n+\n')

    elseif ev == ops.HTTP then
	    local ip = c:ip()
	    print('\nPeer has connected:', ip, '\n+\n')

    elseif ev == ops.WS then
	local s = ...
	local w = deserialize(s)
	if w.cmd == 'error' then print('ERROR', s) end

    elseif ev == ops.ERROR then
	wse.error(c, ...)

    elseif ev == ops.CLOSE then
	print('Connection to', c:ip(), 'is closed\n')

    end
end

local flags = ops.websocket | ops.ssl | ops.cert | ops.key

local server = assert( MGR.bind(WSS, wsfn, flags) )

local function keepalive()
    fd.reduce(MGR.peers, function(p) if isvalid(p) then p:send'Hi' end end)
end

local t1 = assert( MGR.timer(120000, keepalive, true) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

