#! /usr/bin/env lua53

-- Import Section
--
local asJSON	= require'carlos.json'.asJSON
local poll	= require'lzmq'.pollin
local context	= require'lzmq'.context

local format	= require'string'.format
local assert	= assert
local env	= os.getenv

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local CACHE	= {}
local ENDPOINT	= 'ipc://tabs.ipc'
local UPSTREAM  = 'ipc://stream.ipc' -- XXX

--------------------------------
-- Local function definitions --
--------------------------------
--
local function add(query, pid) CACHE[pid] = {pid=pid, query=query} end

local function remove( pid ) CACHE[pid] = nil end



---------------------------------
-- Program execution statement --
---------------------------------
--
local ctx = assert(context())
-- Initialize server
--
local worker = assert(ctx:socket'REP')

assert(worker:bind( ENDPOINT ))

-- Connect to PUBlisher
--
local msgr = assert(ctx:socket'PUSH')

assert(msgr:connect( UPSTREAM ))

assert(msgr:send_msg'Hi TABS')

-- Run loop
--
while true do
    local cmd, pid, query = worker:recv_msg():match'%a+ %w+ [^!]*$'
    worker:send_msg'OK'
    if cmd == 'add' then assert(msgr:send_msg()) end
    if cmd == 'rmv' then assert(msgr:send_msg()) end
    if cmd == 'KILL' then assert(msgr:send_msg'Bye TABS'); break end
end


