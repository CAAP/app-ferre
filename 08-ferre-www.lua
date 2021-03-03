#! /usr/bin/env lua53

-- Import Section
--

local MGR	  = require'lmg'
local socket	  = require'lzmq'.socket
local pollin	  = require'lzmq'.pollin
local rconnect	  = require'redis'.connect
local fromJSON    = require'json'.decode
local json	  = require'json'.encode
local serialize	  = require'carlos.ferre'.serialize
local deserialize = require'carlos.ferre'.deserialize
local asweek	  = require'carlos.ferre'.asweek
local now	  = require'carlos.ferre'.now
local reduce	  = require'carlos.fold'.reduce

local wse	  = require'carlos.ferre.wse'

local posix	  = require'posix.signal'
local concat	  = table.concat
local format	  = string.format
local exit	  = os.exit
local assert	  = assert
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'
local HTTP	  = os.getenv'HTTP_PORT'
local REDIS	  = os.getenv'REDISC'
local WSE	  = os.getenv'WSE_PORT'


-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	 = assert( rconnect(REDIS, '6379') )
local ops	 = MGR.ops

local EGET	 = client:get'tcp:get'

local isvalid 	 = wse.isvalid

local WEEK	 = asweek(now())

-- wse message := json{cmd, ppty1, ppty2, ...}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function broadcast(o)
    local fruit = o.fruit
    local msg = json(o)
    if fruit then
	for _,peer in MGR.peers() do if peer:opt'label' == fruit then peer:send(msg); break; end end
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for _,peer in MGR.peers() do if peer:opt'label' then peer:send(msg); j = j + 1 end end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function switch( s )
    local w = deserialize(s)

    if not(w) then return end

    local cmd = w.cmd

    if cmd == 'updatex' then
--	wss:send( concat(m, ':') ) -- updatex vers overs clave|id b64query
    end

    assert(cmd, 'error: a valid message must include a "cmd" property at least')
    broadcast(w)
end


-------------------------------

local function sendversion(c) c:send(json{cmd='version', version=client:get'app:updates:version', week=WEEK}) end

---------------------------------
-- Program execution statement --
---------------------------------
--
--

local function shutdown()
    print('\nSignal received...\n')
    client:del('mgconn:active', 'app:active', 'app:uuids', 'queue:uuids', 'queue:tickets')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
--
-- Initilize server(s)

local msgr = assert( socket'DEALER' )

assert( msgr:opt('immediate', true) )

assert( msgr:opt('linger', 0) )

assert( msgr:opt('id', 'SSE') )

assert( msgr:connect( STREAM ) )

print('\nSuccessfully connected to', STREAM, '\n')

msgr:send_msg'OK'

-- -- -- -- -- --
--

local function wsefn(c, ev, ...)
    if ev == ops.ACCEPT then
	wse.accept(c) -- connection accepted successfully
	print(c:ip())

    elseif ev == ops.HTTP then
	if isvalid(c) then wse.http(c) -- connection established succesfully
	else c:opt('closing', true) end
--[[
	local _,uri,query,_ = ...
	if uri:match'version.json' then
	    c:send(EGET)
	    c:send()
	    c:send'\n\n'
	end
--]]

    elseif ev == ops.WS then
	local s = ...
	local w = fromJSON(s)
	msgr:send_msgs{w.cmd, serialize(w)}
	print(s, '\n+\n')

    elseif ev == ops.ERROR then
	wse.error(c, ...)

    elseif ev == ops.CLOSE then
	wse.close(c)

    end
end

local flags = ops.websocket -- |ops.ssl|ops.cert|ops.key

local wss = assert( MGR.bind('http://0.0.0.0:'..WSE, wsefn, flags) )

print('\nSuccessfully bound to port', WSE, '\n')

-- -- -- -- -- --
--

local function pingfn()
    print'\n+\ntimer round initiated...\n+\n'
    reduce(MGR.peers, function(peer) if isvalid(peer) then sendversion(peer) end end)
end

local timer = assert( MGR.timer(6000, pingfn, true) )

-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do

    MGR.poll(120)

    pollin({msgr}, 3)

    local events = msgr:opt'events'

    if events.pollin then

	local msg = msgr:recv_msg()

	print('\n+\n\nSTREAM\t', msg, '\n\n+\n')

	switch(msg)

    end

end

