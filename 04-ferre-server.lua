#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local monitor	  = require'carlos.zmq'.monitor

local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context
local pid	  = require'lzmq'.pid
local hex	  = require'lints'.hex

local format	  = require'string'.format
local concat	  = table.concat
local insert	  = table.insert
local remove	  = table.remove
local assert	  = assert
local print	  = print
local pairs	  = pairs
local toint	  = math.tointeger

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5030'
local UPSTREAM   = 'ipc://upstream.ipc'
local SPIES	 = 'inproc://espias'
local HELLO      = sse{content='stream'}

local FRTS	   = {'apple', 'apricot', 'avocado', 'banana', 'berry', 'cherry', 'coconut', 'cucumber', 'fig', 'grape', 'raisin', 'guava', 'pepper', 'corn', 'plum', 'kiwi', 'lemon', 'lime', 'lychee', 'mango', 'melon', 'olive', 'orange', 'durian', 'longan', 'pea', 'peach', 'pear', 'prune', 'pine', 'pomelo', 'pome', 'quince', 'rhubarb', 'mamey', 'soursop', 'granate', 'sapote'}


local FRUITS	 = {}
local SKS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function distill(msg)
    local ev, d = msg:match'(%a+)%s([^!]+)'
    if ev and d then return ev,d
    else return 'SSE',':empty' end
end

local function id2fruit( id, sk )
    local fruit = remove(FRTS) -- pid()
    FRUITS[fruit] = id
    SKS[sk] = fruit
    return fruit
end

local function handshake(server, sk)
    local id = server:recv_msgs()[1] -- receive(server, true)
    local fruit = id2fruit(id, sk)
	send(server, id, HELLO)
	send(server, id, ssevent('fruit', fruit))
    return 'New fruit: '..fruit
end

local function broadcast(server, msg, fruit)
    if fruit then
	send(server, FRUITS[fruit], msg)
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for _,id in pairs(FRUITS) do send(server, id, msg); j = j + 1 end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function switch(msgs, server)
    local m = msgs:recv_msg()

    print(m, '\n')

    local fruit = m:match'^%a+'
    if fruit and FRUITS[fruit] then
	m = m:match'%a+%s([^!]+)' or 'SSE :empty'
	return broadcast(server, ssevent(distill( m )), fruit)
    else
	return broadcast(server, ssevent(distill( m )))
    end
end

local function sayonara(server, sk)
    local fruit = SKS[sk]
    if not fruit then return ':empty' end
    send(server, FRUITS[fruit], '') -- close socket
    FRUITS[fruit] = nil
    SKS[sk] = nil
    insert(FRTS, fruit)
    return fruit
end

local function default(server)
    local id = server:recv_msg(true) -- receive(server, true)
    send(server, id, '') -- close socket
    return 'not supported'
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers
local CTX = context()

local server = assert(CTX:socket'STREAM')
-- -- -- -- -- --
-- * MONITOR *
local spy = monitor(CTX, server, SPIES)
-- -- -- -- -- --
-- ***********
assert( server:notify(false) )

assert( server:alive(true) )

assert( server:linger(0) )

assert( server:timeout(3) )

assert( server:bind( ENDPOINT ) )

print('\nSuccessfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert( msgs:bind( UPSTREAM ) )

print('\nSuccessfully bound to:', UPSTREAM, '\n')

---[[
--
print( 'Starting servers ...', '\n' )

--
while true do
print'+\n'

    if pollin{msgs, spy} then

	if msgs:events() == 'POLLIN' then
	    print( switch(msgs, server), '\n' )
	end

	if spy:events() == 'POLLIN' then
	    local ev, sk, addr = spy:receive() -- receive(spy)
	    print( ev, hex(sk), addr, '\n' )
	    if addr:match'tcp' then
		if ev:match'DISCONNECTED' then
		    print( 'Bye bye', sayonara(server, sk), '\n')
		elseif ev:match'ACCEPTED' then
		    print( handshake(server, sk), '\n' )
--		elseif ev:match'LISTENING' then
--		    print('Event', ev, default(server), '\n')
		end
	    end
	end

    end
end
---]]

