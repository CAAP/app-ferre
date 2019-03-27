#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local getUID	= require'carlos.ferre'.getUID
local now	= require'carlos.ferre'.now
local pollin	= require'lzmq'.pollin
local context	= require'lzmq'.context

local format	= require'string'.format
local concat	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM   = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local QUERIES	 = 'ipc://queries.ipc'

local SUBS	 = {'feed', 'KILL'} -- uid

--------------------------------
-- Local function definitions --
--------------------------------

local function newTicket( msg )
    local pid = msg:match'pid=([^!&]+)&'
    return (getUID() .. pid)
end

---------------------------------
-- Program execution statement --
---------------------------------
-- ZMQ server sockets
--
local CTX = context()

-- Connect to the server(s)
--
local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

fd.reduce(SUBS, function(s) assert(tasks:subscribe(s))  end)

print('Successfully connecto to:', DOWNSTREAM, '\n')
print('And successfully subscribed to:', concat(SUBS, '\t'), '\n')
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert(msgr:connect( UPSTREAM ))

print('Successfully connected to:', UPSTREAM, '\n')
-- -- -- -- -- --
--
local queues = assert(CTX:socket'DEALER')

assert(queues:set_id'WEEK') -- ID sent to DBs router

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
-- -- -- -- -- --
--

while true do
print'+\n'
    if pollin{tasks, queues} then
	if tasks:events() == 'POLLIN' then
	    local msg = tasks:recv_msg()
	    local cmd = msg:match'%a+'
	    if cmd == 'KILL' then
		if msg:match'%s(%a+)' == 'WEEK' then
		    msgr:send_msg'Bye WEEK'
		    break
		end
	    end
--[[
	    if cmd == 'CAJA' then
		local fruit = msg:match'%s(%a+)'
		queues:send_msg(format('feed %s', fruit))
		CACHE.sndkch( msgr, fruit )
		print('CAJA sent to', fruit, '\n')
	    end
--]]
	    if cmd == 'feed' then
--		local fruit = msg:match'%s(%a+)'
--		PEER[#PEER+1] = fruit
		queues:send_msg(msg)
		print('Data forward to queue\n')
	    end
	end
--  XXX must know which PEERs are connected to ME XXX	
	if queues:events() == 'POLLIN' then
	    local msg = queues:recv_msg()
	    if msg:match'feed' then
		msgr:send_msg(msg)
		print(format('feed event sent'))
	    end
	end
    end
end

