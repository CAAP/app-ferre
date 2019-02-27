#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local response	  = require'carlos.html'.response
local stream	  = require'carlos.zmq'.stream
local context	  = require'lzmq'.context
local asJSON	  = require'carlos.json'.asJSON

local assert	  = assert
local concat	  = table.concat
local format	  = string.format

local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5040'
local DOWNSTREAM = 'ipc://downstream.ipc'
local OK	 = response{status='ok'}
local PEERS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function distill(a) return format('%s %s', concat(a, ''):match'GET /(%a+)%?([^%?]+) HTTP') end

local function handshake(server, tasks)
    local id, msg = server.receive()
    id, msg = server.receive()
    if #msg > 0 then tasks:send_msg(distill(msg)); server.send(id, OK); server.close(id) end
    return id
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local server = stream(ENDPOINT, CTX)

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local tasks = assert(CTX:socket'PUB')

assert(tasks:bind( DOWNSTREAM ))

print('Successfully bound to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--
while true do handshake(server, tasks) end

