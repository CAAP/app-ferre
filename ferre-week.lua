#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local newUID	= require'carlos.ferre'.newUID
local uid2week	= require'carlos.ferre'.uid2week
local pollin	= require'lzmq'.pollin
local context	= require'lzmq'.context

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

local SUBS	 = {'feed', 'uid', 'query', 'bixolon', 'KILL'}

--------------------------------
-- Local function definitions --
--------------------------------
local function addWeek(msg)
    local json = msg:match'uid='
    local uid = json and msg:match'uid=([^!&]+)' or msg:match'%s([^!]+)'
    return format(json and '%s&week=%s' or '%s %s', msg, uid2week(uid))
end

local function queryDB(msg)
    local fruit = msg:match'fruit=(%a+)'
    msg = msg:match'%a+%s([^!]+)'
    print('Querying database ...\n')
    local f = assert( popen(format('%s/dump-query.lua %s', APP, msg)) )
    local v = f:read'l' -- :gsub('%s+%d$', '')
    f:close()
    return format('%s query %s', fruit, v)
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
	    elseif cmd == 'query' then
		msgr:send_msg( queryDB(msg) )
	    elseif cmd == 'feed' then
		queues:send_msg(msg)
		print('Data forward to queue\n')
	    elseif cmd == 'uid' or cmd == 'bixolon' then
		queues:send_msg( addWeek(msg) )
		print('Data forward to queue\n')
	    end
	end
	if queues:events() == 'POLLIN' then
	    local msg = queues:recv_msg()
	    local ev = msg:match'%s(%a+)'
	    if msg:match'feed' or ev == 'uid'then --  or ev == 'query' 
		msgr:send_msg(msg)
		print('WEEK event sent\n')
	    end
	end
    end
end

