#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local stream	  = require'carlos.zmq'.stream
local sse	  = require'carlos.html'.response
local ssevent	  = require'carlor.ferre'.ssevent
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
local function handshake(server)
    local id, msg = server.receive()
    local peer = PEERS[id]
    if peer then PEERS[id] = nil; return false; else PEERS[id] = true; end
    id, msg = server.receive() -- receive salutation
    if #msg > 0 then server.send(id, HELLO) end -- if msg[1]:match'GET / ' then 
    return id
end

local function broadcast(server, msg)
    fd.reduce(fd.keys(PEERS), function(_,id) server.send(id, msg) end)
end

local function switch(msgs, server)
    local cmd, msg = msgs:recv_msg():match'(%a+) ([^!]+)'
    print(msg)
    if cmd == "Bye" or cmd == "Hi" then msg = ssevent(cmd, msg) end
    broadcast(server, msg)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize servers
local CTX = context()

local server = stream(ENDPOINT, CTX)

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local msgs = assert(CTX:socket'PULL')

assert(ups:bind( UPSTREAM ))

print('Successfully bound to:', UPSTREAM, '\n')
-- -- -- -- -- --
--
local poll = pollin({server.socket(), msgs}, 2)

while true do
    local j = poll(TIMEOUT)
    print(j, '\n\n')
    if j == 1 then
	if not handshake(server) then print'Bye bye ...\n' end
    elseif j == 2 then
	switch(msgs, server)
    end
end

