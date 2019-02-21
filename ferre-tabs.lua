#! /usr/bin/env lua53

-- Import Section
--
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
local SUBS	 = {'rmv', 'add'}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function distill(msg)
    local cmd, data = decode(msg)
    return cmd, data.pid, data.query
end

local function store(query, pid) CACHE[pid] = {pid=pid, query=query} end

local function delete( pid ) CACHE[pid] = nil end

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

local function sndmsg(e, m) assert(msgr:send_msg(ssevent(e, m))) end

sndmsg('Hi', 'TABS')


-- Run loop
--
while true do
    local cmd, pid, query = distill(tasks:recv_msg())
    if cmd == 'add' then sndmsg('add', query) end
    if cmd == 'rmv' then sndmsg('rmv', pid) end
    if cmd == 'KILL' then sndmsg('Bye', 'TABS'); break end
end

