#! /usr/bin/env lua53

-- Import Section
--

local mgr	= require'lmg'
local socket	= require'lzmq'.socket
local pollin	= require'lzmq'.pollin
local rconnect	= require'redis'.connect

local ssevent	= require'carlos.ferre'.ssevent
local ssefn	= require'carlos.ferre.sse'

local posix	= require'posix.signal'
local concat	= table.concat
local format	= string.format
local exit	= os.exit
local assert	= assert
local print	= print

local STREAM	= os.getenv'STREAM_IPC'
local HTTP	= os.getenv'HTTP_PORT'
local REDIS	= os.getenv'REDISC'
local WSS

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	 = assert( rconnect(REDIS, '6379') )
local ops	 = mgr.ops

local MG	 = 'mgconn:active'
local AP	 = 'app:active'
local EGET	 = client:get'tcp:get'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function distill(msg)
    local ev, d = msg:match'(%a+)%s([^!]+)'
    if ev and d then return ev,d
    else return 'SSE',':empty' end
end

local function broadcast(msg, fruit)
    if fruit then
	for _,peer in mgr.peers() do if peer:id() == fruit then peer:send(msg); break; end end
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for _,peer in mgr.peers() do if peer:id() then peer:send(msg); j = j + 1 end end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function switch( m )
    if 'updatex' == m[1]:match'%a+' then
	wss:send( concat(m, ':') ) -- updatex vers overs clave|id b64query

    end

    local fruit = m:match'^%a+'
    if fruit and client:sismember(MG, fruit) then
	m = m:match'%a+%s([^!]+)' or 'SSE :empty'
	return broadcast(ssevent(distill( m )), fruit)

    else
	return broadcast(ssevent(distill( m )))

    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
--

local function shutdown()
    print('\nSignal received...\n')
    client:del(MG, AP)
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

local function httpfn(c, ev, ...)
    if ev == ops.HTTP then
	local _,uri,query,_ = ...
	print('\nAPP\t', ...)
	if uri:match'version.json' then
	    c:send(EGET)
	    c:send(client:get'app:updates:version')
	    c:send'\n\n'
	else
	    c:send(EGET)
	    c:send'\n\n'
	    msgr:send_msgs{uri:match'%a+', query}
	end
	c:opt('drain', 1)
    end
end

local http = assert( mgr.bind('http://0.0.0.0:'..HTTP, httpfn, ops.http) )

print('\nSuccessfully bound to port', HTTP, '\n')

local sse, SSE = assert( ssefn( mgr ) )

print('\nSuccessfully bound to port', SSE, '\n')

--local wss, WS = assert( wssfn( mgr, client, msgr ) )
--
--print('\nSuccessfully connect to server', WS, '\n')

-- -- -- -- -- --
--

print('\n\n+\n\n')

while true do

    mgr.poll(120)

    pollin({msgr}, 3)

    local events = msgr:opt'events'

    if events.polllin then

	local msg = concat(msgr:recv_msgs(true), ' ')

	print('\n+\n\nSTREAM\t', msg, '\n\n+\n')

	switch(msg)

    end

end

