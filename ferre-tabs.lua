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
local SUBS	 = {'tabs', 'delete'}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function store(pid, msg) CACHE[pid] = msg end

local function delete( pid ) CACHE[pid] = nil end

local function sndkch(msgr) fd.reduce(fd.keys(CACHE), function(m) msgr:send_msg( m ) end) end

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

print('Successfully connected to:', UPSTREAM)

msgr:send_msg('Hi TABS')

---[[
-- Run loop
--
while true do
--    local cmd, pid, query = tasks:recv_msg() -- distill
    local msg = tasks:recv_msg()
print(msg)
    local cmd, pid = msg:match'(%a+)%spid=(%d+)'
    if cmd == 'CACHE' then sndkch( msgr ); goto FIN end
    if cmd == 'KILL' then sndmsg('Bye', 'TABS'); break end
    if cmd == 'delete' then delete( pid ) 
    elseif cmd == 'tabs' then store(pid, msg) end
    msgr:send_msg( msg )
    ::FIN::
end
--]]


