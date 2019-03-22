#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local cache	= require'carlos.ferre'.cache
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
local CACHE	 = cache'Hi WEEK'

local SUBS	 = {'ticket', 'presupuesto', 'CACHE', 'KILL'} -- uid

--------------------------------
-- Local function definitions --
--------------------------------

local function newTicket( msg )
    local pid = msg:match'pid=([^!&]+)&'
    return (getUID() .. pid)
end

local function enroute(msg, queues)
    local cmd = msg:match'%a+'

    if cmd == 'ticket' or cmd == 'presupuesto' then
	queues:send_msg(msg..'&uid='..newTicket(msg))
    end

-- XXX only ask for certain time-duration tickets, in secs
    if cmd == 'feed' then queues:send_msg( msg ) end

    return msg
end

--[[
    if cmd == 'uid' then
	local uid = getUID()
	print('Sending new UID', uid, '\n')
	local fruit = msg:match'%s(%a+)'
	msgr:send_msg(format('%s uid %s', fruit, uid))
    end
--]]

local function switch(msg, msgr)
    local cmd = msg:match'%a+'
    if cmd == 'version' then
	CACHE.store(cmd, msg)
	return 'version data received'
    end
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

assert(queues:connect( QUERIES ))

print('Successfully connected to:', QUERIES, '\n')
-- -- -- -- -- --
--

queues:send_msg'Hi WEEK'

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
	    if cmd == 'CACHE' then
		local fruit = msg:match'%s(%a+)'
		CACHE.sndkch( msgr, fruit )
		print(format('CACHE sent to %s\n', fruit))
	    else print( enroute(msg, queues), '\n' ) end
	end
	if queues:events() == 'POLLIN' then
	    local msg = queues:recv_msg()
	    print( switch(msg, msgr), '\n' )
	end
    end
end

