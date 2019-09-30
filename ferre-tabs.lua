#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'json'.encode
local context	= require'lzmq'.context
local cache	= require'carlos.ferre'.cache

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local PINS	 = cache'Hi PINS'
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local SUBS	 = {'tabs', 'delete', 'msgs', 'pins', 'login', 'CACHE', 'KILL'}

local PIDS	 = {}
local FRUITS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
 -- cmds: tabs, delete, msgs
local function update(pid, cmd, msg)
    if not PIDS[pid] then PIDS[pid] = {} end
    local p = PIDS[pid]
    if cmd == 'delete' and p.tabs then p.tabs = nil
    else p[cmd] = '%s ' .. msg end -- add fruit
end
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

-- Run loop
--
while true do
print'+\n'
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'TABS' then
	    msgr:send_msg('Bye TABS')
	    break
	end
	goto FIN
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	PINS.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
	goto FIN
    end
    local pid = msg:match'pid=(%d+)'
    if cmd == 'pins' then
	PINS.store(pid, msg)
	msgr:send_msg( msg )
    elseif cmd == 'login' then
	local fruit = msg:match'fruit=(%a+)'
	FRUITS[pid] = fruit
	if PIDS[pid] then
	    fd.reduce(fd.keys(PIDS[pid]), function(m) msgr:send_msg(format(m, fruit)) end)
	end
    else -- tabs, delete, msgs
	update(pid, cmd, msg)
	if cmd == 'msgs' then msgr:send_msg(format('%s %s', FRUITS[pid], msg)) end
    end
    print(msg, '\n')
    ::FIN::
end

