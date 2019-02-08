#!/usr/bin/env lua53

-- Import section
local zmq = require'carlos.zmq'
local fd = require'carlos.fold'
local html = require'carlos.html'

local concat = table.concat
local print = print
local assert = assert

-- No more external access after this point
_ENV = nil

-- Local variables for module-only access (private)
local HELLO = html.response{content='stream'}

local PEERS = {}

-- Local function for module-only access
local function handshake(srv, k)
    local id, more = srv.receive()
    if #more == 0 then
	PEERS[id] = true
	id, more = srv.receive()
    end
    print(id, '\t', #more, '\n', concat(more, '\n'), '\n')
    return id
end

---------------------------------
--  SCRIPT running, execution  --
---------------------------------

local server = zmq.stream'tcp://192.168.3.1:8080'

while true do
    local id = handshake(server, 0)
    if id then
	PEERS[id] = server.send(id, HELLO)
    else
	print'ERROR: peer could not be reached!'
    end
end

