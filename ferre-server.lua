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

local format	  = require'string'.format
local concat	  = table.concat
local env	  = os.getenv
local time	  = os.time
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
local FRUITS	 = {}
local CDOWN	 = time()
local RID	 = nil

--------------------------------
-- Local function definitions --
--------------------------------
--
---[[
--]]

local function distill(msg) return msg:match'(%a+)%s([^!]+)' end

local function setRID( server )
    RID = getFruit( FRUITS )
    return server:set_rid( RID )
end

local function handshake(server)
    local id, msg = receive(server)
    msg = concat(msg)

    if #msg > 0 and id == RID then
	send(server, id, HELLO)
	send(server, id, ssevent('fruit', id))
	FRUITS[id] = time() 
	assert( setRID( server ) )
	return 'New id: '..id
    else
	send(server, id, '')
    end
end

local function broadcast(server, msg, fruit)
    if fruit then
	send(server, fruit, msg)
	return format('Broadcast %s to %s', msg, fruit)
    else
	local j = 0
	for id in pairs(FRUITS) do send(server, id, msg); j = j + 1 end
	return format('Message %s broadcasted to %d peers', msg, j)
    end
end

local function purge(fruit, server)
    local now = time()
    FRUITS[fruit] = now

    if (now-CDOWN) < 300 then return FRUITS end

    CDOWN = now -- reset countdown
    local ret =  {}
    for id,t in pairs(FRUITS) do
	if (now-t) < 120 then ret[id] = t
	else send(server, id, '') end
    end

    return ret
end

local function switch(msgs, server)
    local m = msgs:recv_msg()
    local fruit = m:match'^%a+'
    if fruit and FRUITS[fruit] then
	m = m:match'%a+%s([^!]+)' or 'SSE :empty' -- XXX redefine fruit XXX
	FRUITS = purge(fruit, server)
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
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert( server:notify(false) )

assert(server:bind( ENDPOINT ))

assert( setRID( server ) )

print('\nSuccessfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert(msgs:bind( UPSTREAM ))

print('\nSuccessfully bound to:', UPSTREAM, '\n')

---[[
while true do
    print'+\n'
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

