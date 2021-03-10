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
local pcall	  = pcall

local STREAM	  = os.getenv'STREAM_IPC'
local REDIS	  = os.getenv'REDISC'
local WSE	  = os.getenv'WSE_PORT'
local WSPEER	  = os.getenv'WSPEER'


-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	 = assert( rconnect(REDIS, '6379') )
local ops	 = MGR.ops

local EGET	 = client:get'tcp:get'
local QUPS	 = 'queue:ups:'

local isvalid 	 = wse.isvalid

local WEEK	 = asweek(now())

local wsc	 = nil -- placeholder

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
	print('message broadcasted to', fruit)
    else
	local j = 0
	for _,peer in MGR.peers() do if peer:opt'label' then peer:send(msg); j = j + 1 end end
	print('message broadcasted to', j, 'peers')
    end
end

local function toserver(s) if not(wsc:opt'closing') then wsc:send( s ) end end

local function toclients(o)
    if not(o.cmd) then
	toserver(serialize{cmd='error', msg='error: a valid message must include a "cmd"', data=w})
    else
	broadcast(o)
    end
end

local function newup(o)
    local k = QUPS..o.clave
    assert( client:exists(k), 'error: key cannot be nil' )
    o.data = client:lrange(k, 0, -1)
    toserver( serialize(o) ) -- {cmd, version, clave, digest, data}
end

-------------------------------

local function sendversion(c) c:send(json{cmd='version', version=client:get'app:updates:version'}) end -- week=WEEK

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

local router = { updatex=newup,  errorx=toserver }

-- -- -- -- -- --
--

local function wsefn(c, ev, ...)
    if ev == ops.ACCEPT then
	wse.accept(c) -- connection accepted successfully
	print(c:ip())

    elseif ev == ops.HTTP then
	if isvalid(c) then wse.http(c) -- connection established succesfully
	else c:opt('closing', true) end

    elseif ev == ops.WS then
	local s = ...
	local w = fromJSON(s)
	if w.cmd == 'logmeout' then
	    wse.logout(c)
	else
	    msgr:send_msgs{w.cmd, serialize(w)}
	end
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

local function wssfn(c, ev, ...)
    if ev == ops.OPEN then
	wse.open(c)
	c:opt('label', TIENDA)
	c:send'label'

    elseif ev == ops.WS then
	local s = ...
	if s:match'Hi' then
	else
--	    local w = deserialize(s)
--	    msgr:send_msgs{w.cmd, s}
	end
	print('WSS\t', s, '\n+\n')

    elseif ev == ops.ERROR then
	wse.error(c, ...)

    elseif ev == ops.CLOSE then
	wse.close(c)

    end
end

flags = ops.websocket | ops.ssl | ops.ca

wsc = assert( MGR.connect(WSPEER, wssfn, flags) )

print('\nSuccessfully connected to remote peer:', WSPEER, '\n')

-- -- -- -- -- --
--

local function retry() if wsc:opt'closing' then wsc =  assert( MGR.connect(WSPEER, wssfn, flags) ) end end

local t1 = assert( MGR.timer(3000, retry, true) )

-- -- -- -- -- --
--

local function pingfn()
    reduce(MGR.peers, function(peer) if isvalid(peer) then sendversion(peer) end end)
end

local timer = assert( MGR.timer(6000, pingfn, true) )

-- -- -- -- -- --
--

local function switch(s)
    local w = deserialize(s)
    if router[w.cmd] then router[w.cmd](s)
    else router.toclients(w) end
end

print('\n+\n')

while true do

    MGR.poll(120)

    pollin({msgr}, 3)

    local events = msgr:opt'events'

    if events.pollin then

	local msg = msgr:recv_msg()

	print('\n+\n\nSTREAM\t', msg, '\n\n+\n')

	if msg == 'OK' then
	else
	    local done, err = pcall(switch, msg)
	    if not done then print('\nERROR', err, '+\n') end
	end

    end

end

