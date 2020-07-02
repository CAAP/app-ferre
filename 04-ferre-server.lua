#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local receive	  = require'carlos.ferre'.receive
local monitor	  = require'carlos.zmq'.monitor

local context	  = require'lzmq'.context
local sbind	  = require'socket'.bind
local sselect	  = require'socket'.select
local hex	  = require'lints'.hex

local format	  = require'string'.format
local concat	  = table.concat
local insert	  = table.insert
local remove	  = table.remove
local assert	  = assert
local print	  = print
local pairs	  = pairs
local ipairs	  = ipairs
local toint	  = math.tointeger
local time	  = os.time

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 5030 -- 'tcp://*:5030'
local UPSTREAM   = 'ipc://upstream.ipc'
local SPIES	 = 'inproc://espias'
local HELLO      = sse{content='stream'}

local FRTS	   = {'apple', 'apricot', 'avocado', 'banana', 'berry', 'cherry', 'coconut', 'cucumber', 'fig', 'grape', 'raisin', 'guava', 'pepper', 'corn', 'plum', 'kiwi', 'lemon', 'lime', 'lychee', 'mango', 'melon', 'olive', 'orange', 'durian', 'longan', 'pea', 'peach', 'pear', 'prune', 'pine', 'pomelo', 'pome', 'quince', 'rhubarb', 'mamey', 'soursop', 'granate', 'sapote'}

local FRUITS	 = {}

local TT = time()

--------------------------------
-- Local function definitions --
--------------------------------
--

local function send(fruit, msg)
    local sk = FRUITS[fruit]
    if sk and not(sk:send(msg)) then
	sk:close()
	FRUITS[fruit] = nil
	insert(FRTS, fruit)
    end
end

local function distill(msg)
    local ev, d = msg:match'(%a+)%s([^!]+)'
    if ev and d then return ev,d
    else return 'SSE',':empty' end
end

local function sk2fruit( sk )
    local fruit = remove(FRTS)
    FRUITS[fruit] = sk
    return fruit
end

local function handshake(server)
    local sk = assert( server:accept() )
    assert( sk:settimeout(2) )
    local msg, e = sk:receive()
    if not e then
	local fruit = sk2fruit(sk)
	send(fruit, HELLO)
	send(fruit, ssevent('fruit', fruit))
	return 'New fruit: '..fruit
    end
end

local function broadcast(server, msg, fruit)
    if fruit then
	send(fruit, msg)
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for ft in pairs(FRUITS) do send(ft, msg); j = j + 1 end
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

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers

local server = assert( sbind('*', ENDPOINT) )

assert( server:settimeout(0) )

print('\nSuccessfully bound to port:', ENDPOINT, '\n')
-- -- -- -- -- --
--

local CTX = context()

local msgs = assert(CTX:socket'PULL')

assert( msgs:bind( UPSTREAM ) )

print('\nSuccessfully bound to:', UPSTREAM, '\n')

---[[
--
print( 'Starting servers ...', '\n' )

local SKTS = {server, msgs}
SKTS[server] =  function() return handshake(server) end
SKTS[msgs] = function() return switch(msgs, server) end

--
--

while true do

    print'+\n'

    if (TT - time()) > 100 then TT = time(); broadcast(server, ':empty\n') end

    local sks = sselect(SKTS, nil, -1)

    for _,s in ipairs(sks) do print(SKTS[s](), '\n') end

end
---]]

