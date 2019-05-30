#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local getFruit	  = require'carlos.ferre'.getFruit
local purge	  = require'carlos.ferre'.purge
local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context

local format	  = require'string'.format
local concat	  = table.concat
local env	  = os.getenv
local assert	  = assert
local print	  = print
local pairs	  = pairs

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5030'
local UPSTREAM   = 'ipc://upstream.ipc'
local HELLO      = sse{content='stream'}
local TIMEOUT    = 100 -- 100 msecs
local FRUITS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
---[[
--]]

local function distill(msg) return msg:match'(%a+)%s([^!]+)' end

local function handshake(server)
    local id, msg = receive(server)
    msg = concat(msg)

    if #msg > 0 then
	send(server, id, HELLO)
	send(server, id, ssevent('fruit', id))
	FRUITS[id] = true 
	return 'New id: '..id
    end
end

-- XXX Maybe count the number of fails
local function broadcast(server, msg, fruit)
    if fruit then
	send(server, fruit, msg)
	return 'Broadcast: '..msg
    else
	local j = 0
	for id in pairs(FRUITS) do send(server, id, msg); j = j + 1 end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function purge(m, server)
    local ret, i = {}, 0
    for fruit in m:gmatch'[a-z]+' do
	ret[fruit] = true
	i = i + 1
    end
    for fruit in pairs(FRUITS) do
	if not(ret[fruit]) then send(server, fruit, '') end
    end
    return ret, i
end

local function switch(msgs, server)
    local m = msgs:recv_msg()
    if m:match'PONG' then
	FRUITS, m = purge(m, server)
	return format('There are %d connected peers', m)
    end
    local fruit = m:match'%a+'
    if FRUITS[fruit] then
	fruit, m = distill(m)
	broadcast(server, ssevent(distill( m )), fruit)
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
    server:set_rid( getFruit(FRUITS) )
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

