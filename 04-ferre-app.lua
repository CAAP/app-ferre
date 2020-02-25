#! /usr/bin/env lua53

-- Import Section
--

local context	  = require'lzmq'.context
local proxy	  = require'lzmq'.proxy

local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local response	  = require'carlos.html'.response

local assert	  = assert
local concat	  = table.concat
local exec	  = os.execute
local format	  = string.format
local print	  = print

local APP	  = require'carlos.ferre'.APP

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5040'
local DOWNSTREAM = 'ipc://downstream.ipc' --  
--local DOWNSTREAM = 'tcp://*:5050' -- 

local OK	 = response{status='ok'}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function distill(a)
    local data = concat(a)
    if data:match'GET' then
	return format('%s %s', data:match'GET /(%a+)%?([^%?]+) HTTP')
    elseif data:match'POST' then
	return format('%s %s', data:match'POST /(%a+)', data:match'pid=[^%s]+')
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
--
--
-- DUMP --
exec(format('%s/dump-price.lua', APP))

exec(format('%s/dump-people.lua', APP))

exec(format('%s/dump-header.lua', APP))
--
--
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert( server:notify(false) )

assert(server:bind( ENDPOINT ))

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local tasks = assert(CTX:socket'PUSH') -- DEALER

assert( tasks:immediate(true) ) -- queue outgoing to completed connections only

assert(tasks:bind( DOWNSTREAM ))

print('Successfully bound to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--

--assert( proxy(server,tasks) )

---[[
while true do
print'+\n'

    local id, msg = receive(server)
    msg = distill(msg)
    if msg then
	-- send OK
	send(server, id, OK)
	----------------------
	tasks:send_msg(msg)
	----------------------
	print(msg, '\n') -- msg:match'([^%c]+)%c'
    else
	print'Received empty message ;-(\n'
    end
    send(server, id, '') -- close socket

end
--]]

