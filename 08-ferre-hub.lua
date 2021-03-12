#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'
local rconnect	  = require'redis'.connect

local fd	  = require'carlos.fold'
local deserialize = require'carlos.ferre'.deserialize
local serialize = require'carlos.ferre'.serialize
local digest	  = require'carlos.ferre'.digest
local wse	  = require'carlos.ferre.wse'

local concat	  = table.concat
local assert	  = assert
local exit	  = os.exit
local print	  = print
local pcall	  = pcall

local WSS	  = os.getenv'HUB_IP'
local REDIS	  = os.getenv'REDISC'
local TIENDA	  = os.getenv'TIENDA'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

local client	 = assert( rconnect(REDIS, '6379') )

local ops 	= MGR.ops

local PEERS 	= {} -- label, conn

local UPS	= 'app:updates:version'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function toall( s, code )
    local k = 0
    fd.reduce(PEERS, function(peer) peer:send(s, code); k = k + 1 end)
    print('Message broadcasted to', k, 'peer(s)\n+\n')
end

local function topeer( peer, s, code )
    local c = PEERS[peer]
    c:send( s, code )
    print('Message broadcasted to', peer, '\n+\n')
end

local function checkver( o )
    local myv = client:get(UPS)
    if o.version == myv then return false end
    o.version = myv
    return true
end

----------------------------------

local function setgo( c, o, s, code )
    local peer = PEERS[TIENDA]
    if peer and o.digest == digest(o.version, client:get(UPS)) then
	peer:send( s, code )
    end
end

local function uptodate( c, o )
    if checkver(o) then
	o.peer = TIENDA
	c:send( serialize(o) )
    end
end

local function itsme( c, o )
    local label = o.label
    c:opt('label', label)
    PEERS[label] = c
end

local function getpeers( c )
    local a = fd.reduce(fd.keys(PEERS), fd.map(function(c,label) return format('%q\t%s', label, c:ip()) end), fd.into, {})
    c:send(concat(a, '\n'), ops.TEXT)
end

----------------------------------

local router = { peers=getpeers, label=itsme, versionx=uptodate, updatex=setgo }

local function switch( c, s, code )
    print('\nMessage received:', s, '\n+\n')
    local w = deserialize(s)
    local cmd = w.cmd
    if router[cmd] then router[cmd](c, w, s, code)
    else
	if w.peer then topeer(w.peer, s, code)
	else toall(s, code) end
    end
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
	local done, err = pcall(switch, c, ...)
	if not done then print('\nERROR', err, '+\n') end

    elseif ev == ops.ERROR then
	wse.error(c, ...)

    elseif ev == ops.CLOSE then
	print('Connection to', c:ip(), 'is closed\n')
	PEERS[c:opt'label'] = nil

    end
end

local flags = ops.websocket | ops.ssl | ops.cert | ops.key

local server = assert( MGR.bind(WSS, wsfn, flags) )

local function keepalive() fd.reduce(fd.keys(PEERS), function(peer) peer:send'Hi' end) end

local t1 = assert( MGR.timer(120000, keepalive, true) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

