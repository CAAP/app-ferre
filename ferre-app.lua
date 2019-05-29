#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local response	  = require'carlos.html'.response
local urldecode   = require'carlos.ferre'.urldecode
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

--------------------------------
-- Local function definitions --
--------------------------------
--
local function receive(srv)
    local function msgs() return srv:recv_msgs() end -- returns iter, state & counter
    local id, more = assert(srv:recv_msg())
    return id, more and fd.reduce(msgs, fd.into, {}) or {}
end

local function distill(a) return format('%s %s', concat(a, ''):match'GET /(%a+)%?([^%?]+) HTTP') end

local function handshake(server, tasks)
    local id, msg = receive(server)
    msg = distill(msg)
    if msg then
	tasks:send_msg(urldecode(msg))
	server:send_msgs{id, OK}
	server:send_msgs{id, ''}
	return msg:match'([^%c]+)%c'
    else
	return 'Received empty message ;-('
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert( server:notify(false) )

assert(server:bind( ENDPOINT ))

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local tasks = assert(CTX:socket'PUB')

assert(tasks:bind( DOWNSTREAM ))

print('Successfully bound to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--
while true do
print'+\n'
    print(handshake(server, tasks), '\n')
end

