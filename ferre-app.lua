#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local response	  = require'carlos.html'.response
local urldecode   = require'carlos.ferre'.urldecode
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
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
local function distill(a) return format('%s %s', concat(a):match'GET /(%a+)%?([^%?]+) HTTP') end

local function handshake(server, tasks)
    local id, msg = receive(server)
    msg = distill(msg)
    if msg then
	tasks:send_msg(urldecode(msg))
	send(server, id, OK)
	send(server, id, '')
	return msg -- msg:match'([^%c]+)%c'
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

