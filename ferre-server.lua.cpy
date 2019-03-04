#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local server	  = require'carlos.ferre'.server
local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context

local format	  = require'string'.format
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
local PEERS      = {}
local HELLO      = sse{content='stream'}
local TIMEOUT    = 5000 -- 5 secs
local FRUITS	 = {apple=false, apricot=false, avocado=false, banana=false, berry=false, cherry=false, coconut=false, cucumber=false, fig=false, grape=false, raisin=false, guava=false, pepper=false, corn=false, plum=false, kiwi=false, lemon=false, lime=false, lychee=false, mango=false, melon=false, nectarine=false, orange=false, clementine=false, tangerine=false, pea=false, peach=false, pear=false, prune=false, pine=false, pomelo=false, tamarindo=false, sapote=false}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function getFruit(id)
    local _,k = fd.first(fd.keys(FRUITS), function(x) return not(x) end)
    FRUITS[k] = id
    return k
end

local function distill(msg) return msg:match'(%a+)%s([^!]+)' end

local function receive(srv)
    local function msgs() return srv:recv_msgs() end -- returns iter, state & counter
    local id, more = srv:recv_msg()
    if id and more then more = fd.reduce(msgs, fd.into, {}) end
    return id, more
end

local function handshake(server)
    local id, msg = receive(server)
    if not id then return false end -- ERROR maybe due to NOWAIT
    local peer = PEERS[id]
    if peer then FRUITS[peer] = false; PEERS[id] = nil; return false; else PEERS[id] = getFruit(id); end
    id, msg = receive(server) -- receive salutation
    if id and #msg > 0 then
	server:send_msgs{id, HELLO}
	server:send_msgs{id, ssevent('fruit', PEERS[id])} -- format('%q', PEERS[id])
	print('New peer:', PEERS[id], '\n')
	return id
    end
    return false
end

local function broadcast(server, msg)
    for id, peer in pairs(PEERS) do
	if not(server:send_msgs({id, msg}, 'NOWAIT')) then
	    PEERS[id] = nil; FRUITS[peer] = false
	end
    end
    return true
end

local function switch(msgs, server)
    local m = msgs:recv_msg'NOWAIT'
    if m then return broadcast(server, ssevent(distill( m )))
    else return false end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert(server:recv_tout(TIMEOUT))

assert(server:bind( ENDPOINT ))

assert(server:recv_tout(TIMEOUT))

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert(msgs:bind( UPSTREAM ))

print('Successfully bound to:', UPSTREAM, '\n')
-- -- -- -- -- --
--

---[[
while true do
    if pollin{server, msgs} then
	if server:events() then
	    if not handshake(server) then print'Bye bye ...\n' end
	end
	if msgs:events() and switch(msgs, server) then print'Event broadcasted ...\n' end
    end
end
--]]

