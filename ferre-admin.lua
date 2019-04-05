#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local pollin	= require'lzmq'.pollin
local context	= require'lzmq'.context
local dbconn	= require'carlos.ferre'.dbconn
local cache	= require'carlos.ferre'.cache

local format	= require'string'.format
local concat	= table.concat
local insert	= table.insert
local remove	= table.remove
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM   = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local QUERIES	 = 'ipc://queries.ipc'

local ROOT	 = '/var/www/htdocs/app-ferre/admin/json'
local SUBS	 = {'update', 'CACHE', 'KILL'}
local CACHE	 = cache'Hi ADMIN'

--------------------------------
-- Local function definitions --
--------------------------------
local function escape(a) return fd.reduce(a, fd.map(function(x) return format('%q',x) end), fd.into, {}) end

local function cacheHEADER()
    local conn =  dbconn'ferre'
    local ret = escape(conn.header'datos')
    remove(ret) -- uidSAT
    insert(ret, 6, remove(ret)) -- rebaja
    remove(ret) -- costol
    ret = concat(ret, ', ')
    CACHE.store( 'header', format('%s [%s]', 'header', ret) )
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

assert(queues:set_id'ADMIN') -- ID sent to ROUTER skt

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
-- -- -- -- -- --
--

cacheHEADER()

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
	    end
	    if cmd == 'CACHE' then
		local fruit = msg:match'%s(%a+)'
		CACHE.sndkch( msgr, fruit )
		print('CACHE sent to', fruit, '\n')
	    end
	    if cmd == 'update' then
		queues:send_msg( msg )
		print('Message forward to queue\n')
	    end
	end
	if queues:events() == 'POLLIN' then
	    local msg = queues:recv_msg()
	    local ev = msg:match'%s(%a+)'
	    if ev == 'header' or ev == 'update' then
		msgr:send_msg(msg)
		print('WEEK event sent\n')
	    end
	end
    end
end

