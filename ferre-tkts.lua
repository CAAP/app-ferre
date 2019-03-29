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
local function newUID( pid ) return date('%FT%TP', now())..pid end

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
    end
    if cmd == 'ticket' or cmd == 'presupuesto' then
	local pid = msg:match'pid=(%d)'
	queues:send_msg(msg .. '&uid=' .. newUID( pid ))
	print('Data forward to queue\n')
    end
--[[
    if cmd == 'uid' then -- UNUSED not YET XXX
	local fruit = msg:match'%s(%a+)'
	msgr:send_msg(format('%s uid %s', fruit, newUID()))
	print('UID sent to', fruit, '\n')
    end
--]]
end

