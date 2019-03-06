#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local context	= require'lzmq'.context
local cache	= require'carlos.ferre'.cache
local decode	= require'carlos.ferre'.decode

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local CACHE	 = cache'Hi TABS' -- {carl='Hi TABS'}
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local SUBS	 = {'tabs', 'delete', 'CACHE', 'KILL'}

--------------------------------
-- Local function definitions --
--------------------------------
--
CACHE.tabs = CACHE.store
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
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
	goto FIN
    end
    local pid = msg:match'pid=(%d+)'
    CACHE[cmd]( pid, msg )
--    if cmd == 'delete' then cache.delete( pid )
--    elseif cmd == 'tabs' then cache.store(pid, msg) end
    msgr:send_msg( msg )
    print(msg, '\n')
    ::FIN::
end

