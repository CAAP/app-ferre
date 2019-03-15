#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local now	= require'carlos.ferre'.now
local context	= require'lzmq'.context

local format	= require'string'.format
local concat 	= table.concat
local date	= os.date
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local QUERIES	 = 'ipc://queries.ipc'
local TBNAME	 = 'tickets'

local SUBS	 = {'ticket', 'presupuesto', 'KILL'} -- date, uid, utime, urtime

--------------------------------
-- Local function definitions --
--------------------------------
--
local function newUID() return date('%FT%TP', now()) end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize server
local CTX = context()

local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

fd.reduce(SUBS, function(s) assert(tasks:subscribe(s))  end)

print('Successfully connected to:', DOWNSTREAM)
print('And successfully subscribed to:', concat(SUBS, '\t'), '\n')
-- -- -- -- -- --
--
-- Connect to PUBlisher
local msgr = assert(CTX:socket'PUSH')

assert(msgr:connect( UPSTREAM ))

print('Successfully connected to:', UPSTREAM, '\n')
-- -- -- -- -- --
--
local queues = assert(CTX:socket'DEALER')

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
-- -- -- -- -- --
--
-- NO CACHE
msgr:send_msg'Hi TKTS'

-- Run loop
--
while true do
print'+\n'
    pollin{tasks, queues}
    if tasks:events() == 'POLLIN' then
	local msg = tasks:recv_msg()
	local cmd = msg:match'%a+'
	if cmd == 'KILL' then
	    if msg:match'%s(%a+)' == 'TKTS' then
		msgr:send_msg('Bye TKTS')
		break
	    end
	end
	if cmd == 'ticket' or cmd == 'presupuesto' then
	    queues:msg_send(msg)
	    print('Data forward to queue\n')
	end
	if cmd == 'uid' then
	    local fruit = msg:match'%s(%a+)'
	    msgr:send_msg(format('%s uid %s', fruit, newUID()))
	    print('UID sent to', fruit, '\n')
	end
    end
    if queues:events() == 'POLLIN' then
    end
end

