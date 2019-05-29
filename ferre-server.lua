#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local receive	  = require'carlos.ferre'.receive
local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context

local format	  = require'string'.format
local env	  = os.getenv
local assert	  = assert
local print	  = print
local pairs	  = pairs

local concat = table.concat
local pcall = pcall

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5030'
local UPSTREAM   = 'ipc://upstream.ipc'
local HELLO      = sse{content='stream'}
local TIMEOUT    = 100 -- 100 msecs
local FRUITS	 = {apple=false, apricot=false, avocado=false, banana=false, berry=false, cherry=false, coconut=false, cucumber=false, fig=false, grape=false, raisin=false, guava=false, pepper=false, corn=false, plum=false, kiwi=false, lemon=false, lime=false, lychee=false, mango=false, melon=false, olive=false, orange=false, durian=false, longan=false, pea=false, peach=false, pear=false, prune=false, pine=false, pomelo=false, pome=false, quince=false, rhubarb=false, mamey=false, soursop=false, granate=false, sapote=false}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function getFruit()
    local _,k = fd.first(fd.keys(FRUITS), function(x) return not(x) end)
    return k or 'orphan'
end

local function distill(msg) return msg:match'(%a+)%s([^!]+)' end

local function handshakeORIG(server)
    local id, msg = receive(server)
    msg = msg and concat(msg) or ''
    if #msg > 0 then print('message:', concat(msg, ' ')) end
    local peer = FRUITS[id]
    if peer then FRUITS[id] = false; return 'Bye '..id; else FRUITS[id] = true end

    id, msg = receive(server) -- receive salutation
    if id and #msg > 0 then
	server:send_msgs{id, HELLO}
	server:send_msgs{id, ssevent('fruit', id)}
	return 'New id: '..id
    end
    return 'Null message'
end

local function handshake(server)
    local id, msg = receive(server)
    msg = msg and concat(msg) or ''

    if #msg > 0 then
	server:send_msgs{id, HELLO}
	server:send_msgs{id, ssevent('fruit', id)}
	FRUITS[id] = true 
	return 'New id: '..id
    end
end

-- XXX Maybe count the number of fails
local function broadcast(server, msg, fruit)
    local function send2fruit(id) if not pcall(function() server:send_msgs{id, msg}end) then FRUITS[id] = false end end

    if fruit then send2fruit(fruit)
    else for id in pairs(FRUITS) do send2fruit(id) end end

    return 'Broadcast: '..msg
end

local function switch(msgs, server)
    local m = msgs:recv_msg()
    local fruit = m:match'%a+'
    if FRUITS[fruit] then
	fruit, m = distill(m)
	broadcast(server, ssevent(distill( m )), fruit) --  XXX CAUSES error ON HI: distill( m ) or m
	return 'Broadcast message to '..fruit
    else
	return broadcast(server, ssevent(distill( m )))
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert( server:notify(false) )

assert(server:bind( ENDPOINT ))

print('\nSuccessfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert(msgs:bind( UPSTREAM ))

print('\nSuccessfully bound to:', UPSTREAM, '\n')

---[[
while true do
    print'+\n'
    server:set_rid( getFruit() )
    if pollin{server, msgs} then
	if server:events() == 'POLLIN' then
	    print( handshake(server), '\n' )
	end
	if msgs:events() == 'POLLIN' then
	    print( switch(msgs, server), '\n' )
	end
    end
end
---]]

