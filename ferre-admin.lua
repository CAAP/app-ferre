#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local pollin	= require'lzmq'.pollin
local context	= require'lzmq'.context
local cache	= require'carlos.ferre'.cache

local format	= string.format
local popen	= io.popen
local concat	= table.concat
local assert	= assert

local print	= print

local APP	= require'carlos.ferre'.APP

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM   = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local QUERIES	 = 'ipc://queries.ipc'

local ROOT	 = '/var/www/htdocs/app-ferre/admin/json'
local SUBS	 = {'update', 'header', 'CACHE', 'KILL'}
local CACHE	 = cache'Hi ADMIN'

--------------------------------
-- Local function definitions --
--------------------------------

local function getHeader()
    local f = popen(format('%s/dump-header.lua', APP))
    local v = f:read'l'
    f:close()
    return v
end

---------------------------------
-- 	Dump header to CACHE   --
---------------------------------

CACHE.store('HDR', getHeader())

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

assert(queues:set_id'ADMIN') -- ID sent to ROUTER skt

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
--
-- -- -- -- -- --
--

while true do
print'+\n'
    if pollin{tasks, queues} then
	if tasks:events() == 'POLLIN' then
	    local msg = tasks:recv_msg()
	    local cmd = msg:match'%a+'
	    if cmd == 'KILL' then
		if msg:match'%s(%a+)' == 'ADMIN' then
		    msgr:send_msg'Bye ADMIN'
		    break
		end
	    elseif cmd == 'CACHE' then
		local fruit = msg:match'%s(%a+)'
		CACHE.sndkch( msgr, fruit )
		print('CACHE sent to', fruit, '\n')
--[[
	    elseif cmd == 'header' then
		local fruit = msg:match'%s(%a+)'
		msgr:send_msg( format('%s %s', fruit, HEADER) )
		print('HEADER sent\n')
--]]
	    elseif cmd == 'update' then
		queues:send_msg( msg )
		print('Message forward to queue\n')
	    end
	end
	if queues:events() == 'POLLIN' then
	    local msg = queues:recv_msg()
	    local ev = msg:match'%s(%a+)'
	    if ev == 'update' then
		msgr:send_msg(msg)
		print'UPDATE event sent\n'
	    end
	end
    end
end

