#! /usr/bin/env lua53

-- Import Section
--

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

local getuservalue = debug.getuservalue

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = env'HTTP_PORT'
local SSE	 = env'SSE_PORT'
local STREAM	 = env'STREAM_IPC'
local events	 = mgr.events

local ESTREAM	 = concat({"Content-Type: text/event-stream",
"Connection: keep-alive", "Cache-Control: no-cache",
"Access-Control-Allow-Origin: *", "Access-Control-Allow-Methods: GET"}, "\r\n")

local EGET	 = concat({"Content-Type: text/plain",
"Cache-Control: no-cache", "Access-Control-Allow-Origin: *",
"Access-Control-Allow-Methods: GET"}, "\r\n")

local FRTS	 = {'apple', 'apricot', 'avocado', 'banana', 'berry', 'cherry', 'coconut', 'cucumber', 'fig', 'grape', 'raisin', 'guava', 'pepper', 'corn', 'plum', 'kiwi', 'lemon', 'lime', 'lychee', 'mango', 'melon', 'olive', 'orange', 'durian', 'longan', 'pea', 'peach', 'pear', 'prune', 'pine', 'pomelo', 'pome', 'quince', 'rhubarb', 'mamey', 'soursop', 'granate', 'sapote'}


local FRUITS = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function conn2fruit( c )
    local fruit = remove(FRTS) -- pid()
    local skt = c:sock()
    FRUITS[skt] = fruit
    FRUITS[fruit] = skt
    return fruit
end

local function sayoonara( fruit )
    local skt = FRUITS[fruit]
    FRUITS[fruit] = nil
    FRUITS[skt] = nil
    insert(FRTS, fruit)
    return fruit
end

local function broadcast(msg, fruit)
    if fruit then
	local skt = FRUITS[fruit]
	for c in mgr.iter() do if c:sock() == skt then c:send(msg); break; end end
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for c in mgr.iter() do if FRUITS[c:sock()] then c:send(msg); j = j + 1 end end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function distill(msg)
    local ev, d = msg:match'(%a+)%s([^!]+)'
    if ev and d then return ev,d
    else return 'SSE',':empty' end
end

local function switch( m )
    local fruit = m:match'^%a+'
    if fruit and FRUITS[fruit] then
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
	local fruit = assert( FRUITS[c:sock()] )
	c:reply(200, '', ESTREAM)
	c:send('\n\n')
	c:send( ssevent('fruit', fruit) )
	print'connection established\n'

    elseif ev == events.CLOSE then
	local fruit = assert( FRUITS[c:sock()] )
	print('bye bye', sayoonara(fruit), '\n')

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

    pollin({msgr}, 5)

    if msgr:events() == 'POLLIN' then

	local msg = concat(msgr:recv_msgs(true), '&')

	print(msg, '\n')

	print(switch(msg), '\n')

    end
end

