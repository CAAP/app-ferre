#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'

local fd	  = require'carlos.fold'
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

local isvalid 	= wse.isvalid

local PEERS 	= {} -- label, conn

--------------------------------
-- Local function definitions --
--------------------------------
--
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
--	if c:opt'label' then
	    print('\nNew connection established:', c:opt'label', '\n+\n')
--	else c:opt('closing', true) end

    elseif ev == ops.HTTP then
--	if isvalid(c) then
	    local ip = c:ip()
	    print('\nPeer has connected:', ip, '\n+\n')
--	    PEERS[c:opt'label'] = c
--	else c:opt('closing', true) end

    elseif ev == ops.WS then
--	switch( c, ... )
	print( ... )

    elseif ev == ops.ERROR then
	wse.error(c, ...)

    elseif ev == ops.CLOSE then
	print('Connection to', c:ip(), 'is closed\n')
--	if c:opt'label' then PEERS[c:opt'label'] = nil end

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

