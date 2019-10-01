#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local newUID	= require'carlos.ferre'.newUID
local context	= require'lzmq'.context

local format	= require'string'.format
local concat 	= table.concat
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
local queues = assert(CTX:socket'DEALER')

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
-- -- -- -- -- --
--

-- Run loop
--
while true do
print'+\n'
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'TKTS' then
	    print'Bye TKTS'
	    break
	end
    else
--    end
--    if cmd == 'ticket' or cmd == 'presupuesto' then
	local pid = msg:match'pid=([%d%a]+)'
	if pid then -- received messages saying presupuesto nil ??? XXX
	    queues:send_msg(format('%s&uid=%s%s', msg, newUID(), pid))
	    print('Data forward to queue\n')
	end
    end
end

