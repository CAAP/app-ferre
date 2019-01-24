--module setup

-- Import section
local zmq = require'lzmq'
local fd = require'carlos.fold'
local html = require'carlos.html'

local concat = table.concat

-- No more external access after this point
_ENV = nil

-- Local variables for module-only access (private)
local HELLO = html.response{content='stream'}

local PEERS = {}

-- Local function for module-only access
local function handshake(srv)
    local id, more = srv.receive()
    if more then
	local PEERS[id] = true
	print(id, '\n', concat(more, '\n'))
	return true
    else
	return handshake(srv)
    end
end

---------------------------------
--  SCRIPT running, execution  --
---------------------------------

local server = zmq.stream'tcp://localhost:8080'

while true do
    handshake(server)
end


