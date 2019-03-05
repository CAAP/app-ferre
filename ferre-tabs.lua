#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local poll	= require'lzmq'.pollin
local context	= require'lzmq'.context
local ssevent	= require'carlos.ferre'.ssevent
local decode	= require'carlos.ferre'.decode

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert
local env	= os.getenv

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local CACHE	 = {}
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local SUBS	 = {'tabs', 'delete', 'CACHE', 'KILL'}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function store(pid, msg) CACHE[pid] = msg end

local function delete( pid ) CACHE[pid] = nil end

local function tofruit( fruit, m ) return format('%s %s', fruit, m) end

local function sndkch(msgr, fruit) fd.reduce(fd.keys(CACHE), function(m) msgr:send_msg(tofruit(fruit, m)) end) end

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

msgr:send_msg('Hi TABS')

---[[
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
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
	goto FIN
    end
    local pid = msg:match'pid=(%d+)'
    if cmd == 'delete' then delete( pid ) 
    elseif cmd == 'tabs' then store(pid, msg) end
    msgr:send_msg( msg )
    print(msg, '\n')
    ::FIN::
end
--]]

