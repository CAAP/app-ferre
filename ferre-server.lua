#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local getFruit	  = require'carlos.ferre'.getFruit
local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context
local sleep	  =require'lbsd'.sleep

local format	  = require'string'.format
local concat	  = table.concat
local assert	  = assert
local print	  = print
local pairs	  = pairs
local toint	  = math.tointeger

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5030' -- 5030
local UPSTREAM   = 'ipc://upstream.ipc'
local SPIES	 = 'inproc://espias'
local HELLO      = sse{content='stream'}
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
    local fruit = getFruit( FRUITS )
    FRUITS[fruit] = id
    SKS[sk] = fruit
    return fruit
end

local function handshake(server, sk)
    local id, msg = receive(server)
	send(server, id, HELLO)
	send(server, id, ssevent('fruit', id2fruit(id, sk)))
    return 'New fruit: '..SKS[sk]
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
    local fruit = m:match'^%a+'
    if fruit and FRUITS[fruit] then
	m = m:match'%a+%s([^!]+)' or 'SSE :empty'
	return broadcast(server, ssevent(distill( m )), fruit)
    else
	return broadcast(server, ssevent(distill( m )))
    end
end

local function sayonara(sk)
    local fruit = SKS[sk]
    if not fruit then return ':empty' end
    FRUITS[fruit] = nil
    SKS[sk] = nil
    return fruit
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
local spy = assert(CTX:socket'PAIR')
assert( server:monitor( SPIES ) )
assert( spy:connect( SPIES ) )
-- -- -- -- -- --
-- ***********
assert( server:notify(false) )

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
sleep(2)


--
local flag
while true do

    print'+\n'

    if pollin{server, msgs, spy} then

	if msgs:events() == 'POLLIN' then
	    print( switch(msgs, server), '\n' )
	end

	if spy:events() == 'POLLIN' then
	    local ev, mm = receive(spy)
	    if mm[1]:match'tcp' then
		local sk = toint(ev:match'%d+$')
		if ev:match'DISCONNECTED' then
		    print( ev, '\n' )
		    print( 'Bye bye', sayonara(sk), '\n')
		elseif ev:match'ACCEPTED' then
		    print( ev, '\n' )
		    if flag then flag = nil; print( handshake(server, sk), '\n' ) else flag = sk end
		end
	    end
	end

	if server:events() == 'POLLIN' then
	    if flag then print( handshake(server, flag), '\n' ); flag = nil else flag = true end
	end

    end
end
---]]


--[[

--]]
