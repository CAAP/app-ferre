#! /usr/bin/env lua53

-- Import Section
--

local redis	= require'redis'
local mgr	= require'lmg'
local context	= require'lzmq'.context
local pollin	= require'lzmq'.pollin

local ssevent	  = require'carlos.ferre'.ssevent

local posix	= require'posix.signal'
local concat	= table.concat
local remove	= table.remove
local insert	= table.insert
local format	= string.format
local exit	= os.exit
local env	= os.getenv
local assert	= assert
local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = env'HTTP_PORT'
local SSE	 = env'SSE_PORT'
local STREAM	 = env'STREAM_IPC'
local events	 = mgr.events

local client	 = assert( redis.connect('127.0.0.1', '6379') )

local ESTREAM	 = assert( client:get'tcp:sse' )
local EGET	 = assert( client:get'tcp:get' )
local MG	 = 'mgconn:active'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function conn2fruit( c )
    local fruit = client:rpoplpush('const:fruits', 'const:fruits')

    local skt = c:sock()
    client:hmset(MG, skt, fruit, fruit, skt)
    return fruit

    local fruit = remove(FRTS) -- pid()
    local skt = c:sock()
    FRUITS[skt] = fruit
    FRUITS[fruit] = skt
    return fruit
end

local function connectme( c )
    local fruit = assert( client:hget(MG, c:sock()) )
    c:reply(200, '', ESTREAM)
    c:send('\n\n')
    c:send( ssevent('fruit', fruit) )
end

local function sayoonara( c )
    local skt = c:sock()
    local fruit = assert( client:hget(MG, skt) )
    local pid = client:hget(fruit, 'pid') or 'NaP'
    client:hdel(MG, skt, fruit, pid)
    return fruit
end

local function distill(msg)
    local ev, d = msg:match'(%a+)%s([^!]+)'
    if ev and d then return ev,d
    else return 'SSE',':empty' end
end

local function broadcast(msg, fruit)
    if fruit then
	local skt = client:hget(MG, fruit)
	for c in mgr.iter() do if c:sock() == skt then c:send(msg); break; end end
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for c in mgr.iter() do if client:hexists(MG, c:sock()) then c:send(msg); j = j + 1 end end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function switch( m )
    local fruit = m:match'^%a+'
    if fruit and client:hexists(MG, fruit) then
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
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
--
-- Initilize server(s)

local CTX = assert( context() )

local msgr = assert( CTX:socket'DEALER' )

assert( msgr:immediate(true) )

assert( msgr:linger(0) )

assert( msgr:set_id'SSE' )

assert( msgr:connect( STREAM ) )

print('\nSuccessfully connected to', STREAM, '\n')

msgr:send_msg'OK'

-- -- -- -- -- --
--

local function frontend(c, ev, ...)
    if ev == events.REQUEST then
	local _,uri,query,_ = ...
	print('\nAPP\t', ...)
	c:reply(200, 'OK', EGET, true)
	msgr:send_msgs{'app', uri:match'%a+', query}
    end
end

local function backend(c, ev, ...)
    if ev == events.ACCEPT then
	local fruit = conn2fruit(c)
	print('New fruit:', fruit, '\n')

    elseif ev == events.REQUEST then
	connectme(c)
	print'connection established\n'

    elseif ev == events.CLOSE then
	print('bye bye', sayoonara(c), '\n')

    end
end

local app = assert( mgr.bind(ENDPOINT, frontend, 'http') )

print('\nSuccessfully bound to port', ENDPOINT, '\n')

local sse = assert( mgr.bind(SSE, backend, 'http') )

print('\nSuccessfully bound to port', SSE, '\n')

-- -- -- -- -- --
--

while true do

    mgr.poll(12)

    pollin({msgr}, 3)

    if msgr:events() == 'POLLIN' then

	local msg = concat(msgr:recv_msgs(true), ' ')

	print(msg, '\n')

	print(switch(msg), '\n')

    end
end

