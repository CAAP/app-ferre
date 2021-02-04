#! /usr/bin/env lua53

-- Import Section
--
local MGR	  = require'lmg'
local posix	  = require'posix.signal'
local dN	  = require'binser'.deserializeN
local fb64	  = require'lints'.fromB64

local concat	  = table.concat
local unpack	  = table.unpack
local assert	  = assert
local exit	  = os.exit
local print	  = print

local TIENDA	  = os.getenv'TIENDA'
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

local function ping(c)
    return function()
	local m = format('vers:%s:%s', TIENDA, client:get'app:updates:version') -- client XXX
	c:send(m)
    end
end

local function raw(s) return s:match'Y%d+Wd+', s:match':(%d+)' end

local function comp(a,b)
    local aw, av = raw(a)
    local bw, bv = raw(b)
    return aw == bw and (av > bv and 1 or (av == bv and 0 or -1)) or (aw > bw and 1 or -1)
end

local function deserialize(s)
    local a,i = dN(fb64(s), 1)
    return a
end

local function switch( c, msg, code )

    print('Message received:', msg, '\n')

    if msg:match'updatex'  then
	local v = client:get'app:updates:version' -- client XXX
	local vers, overs, clave, query = msg:match'updatex:(%w+):(%w+):(%w+):(%w+)'
	if v == overs then
	    local k = 'queue:uuids:'..clave
	    client:rpush(k, unpack(deserialize(query))) -- client XXX
	    client:expire(k, 20)
	    msgr:send{'DB', 'updatex', clave, vers} -- msgr XXX

	elseif comp(overs, v) == 1 then
	    local m = format('vers:%s:%s', TIENDA, v)
	    c:send(m)

	end
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
--]]
    elseif ev == ops.CLOSE then
	print('Connection to peer:', c:ip(), 'closed\nRetrying ...\n')
--	MGR.timer(3000, function() MGR.connect(WSS, wsfn, ops.websocket|ops.ssl|ops.ca) end)

    end
end

local wss = assert( MGR.connect(WSS, wsfn, ops.websocket|ops.ssl|ops.ca) )

wss:opt('label', TIENDA)

MGR.timer( 120000, ping(wss) )

--
-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do MGR.poll(1000) end

