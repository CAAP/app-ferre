#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local sse	  = require'carlos.html'.response
local ssevent	  = require'carlos.ferre'.ssevent
local pollin	  = require'lzmq'.pollin
local context	  = require'lzmq'.context

local format	  = require'string'.format
local env	  = os.getenv
local assert	  = assert
local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT   = 'tcp://*:5030'
local UPSTREAM   = 'ipc://upstream.ipc'
local PEERS      = {}
local HELLO      = sse{content='stream'}
local TIMEOUT    = 5000 -- 5 secs

--------------------------------
-- Local function definitions --
--------------------------------
--
local function distill(msg) return msg:match'(%a+)%s([^!]+)' end

local function receive(srv)
    local function msgs() return srv:recv_msgs() end -- returns iter, state & counter
    local id, more = assert(srv:recv_msg())
    if more then more = fd.reduce(msgs, fd.into, {}) end
    return id, more
end

local function handshake(server)
    local id, msg = receive(server)
    local peer = PEERS[id]
    if peer then PEERS[id] = nil; return false; else PEERS[id] = true; end
    id, msg = receive(server) -- receive salutation
    if #msg > 0 then server:send_msgs{id, HELLO} end
    return id
end

local function broadcast(server, msg)
    fd.reduce(fd.keys(PEERS), function(_,id) server:send_msgs{id, msg} end)
end

local function switch(msgs, server) broadcast(server, ssevent(distill( msgs:recv_msg() ))) end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert(server:bind( ENDPOINT ))

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert(msgs:bind( UPSTREAM ))

print('Successfully bound to:', UPSTREAM, '\n')
-- -- -- -- -- --
--

--print( msgs:recv_msg() )
--local poll = pollin{msgs, server.socket()}

---[[
while true do
    if pollin{server, msgs} then
	if server:events() then
	    if not handshake(server) then print'Bye bye ...\n' end
	end
	if msgs:events() then
	    print( msgs:recv_msg() )
	end
    end
end
--]]

