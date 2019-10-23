#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local response	  = require'carlos.html'.response
local urldecode   = require'carlos.ferre'.urldecode
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local context	  = require'lzmq'.context
local asJSON	  = require'carlos.json'.asJSON

local tabs	= require'carlos.ferre.tabs'

local assert	  = assert
local exec	  = os.execute
local format	  = string.format
local concat	  = table.concat
local format	  = string.format

local print	  = print

local APP	  = require'carlos.ferre'.APP

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5040'
local DOWNSTREAM = 'ipc://downstream.ipc'
local UPSTREAM   = 'ipc://upstream.ipc'
local OK	 = response{status='ok'}

local TASKS = { ticket=true, presupuesto=true,
		update=true, bixolon=true }

local TABS = {  tabs=true, delete=true, msgs=true,
		pins=true, login=true, CACHE=true }

local CMDS = {  adjust=true, version=true,
		feed=true, ledger=true, uid=true,
		query=true, CACHE=true }

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

local function handshake(server, tasks, msgr)
    local id, msg = receive(server)
    msg = distill(msg)
    if msg then
	-- send OK  & close socket
	send(server, id, OK)
	send(server, id, '')
	-- divide & conquer
	local cmd = msg:match'%a+'
	if TASKS[cmd] then
	    tasks:send_msg(urldecode(msg))
	    goto ::FIN::
	end
	if TABS[cmd] then tabs(msg, msgr) end

	::FIN::
	return msg -- msg:match'([^%c]+)%c'
    else
	return 'Received empty message ;-('
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
local tasks = assert(CTX:socket'PUB')

assert(tasks:bind( DOWNSTREAM ))

print('Successfully bound to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')
--- -- -- -- -- --
--
while true do
print'+\n'
    print(handshake(server, tasks, msgr), '\n')
end

