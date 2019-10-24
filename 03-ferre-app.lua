#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local response	  = require'carlos.html'.response
local urldecode   = require'carlos.ferre'.urldecode
local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local queryDB	  = require'carlos.ferre'.queryDB
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

local FEED = { feed=true, ledger=true, uid=true }

local TABS = {  tabs=true, delete=true, msgs=true,
		pins=true, login=true, CACHE=true }

local CMDS = {  adjust=true, version=true,
		CACHE=true }

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

local function dump(cmd, frt, uid)
    exec(format('%s/dump-feed.lua %s %s %s', APP, cmd, frt, uid))
end

local function sndmsg( cmd, fruit)
    return format('%s %s %s-feed.json', fruit, cmd, fruit)
end

local function feed(cmd, msg, msgr)
    if cmd == 'feed' then
	local fruit = msg:match'%s(%a+)'
	dump(cmd, fruit, '')
	msgr:send_msg( sndmsg(cmd, fruit) )

    elseif cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	dump(cmd, fruit, uid)
	msgr:send_msg( sndmsg(cmd, fruit) )

    elseif cmd == 'ledger' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	dump(cmd, fruit, uid)
	msgr:send_msg( sndmsg(cmd, fruit) )

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
	if cmd == 'query' then
	    msgr:send_msg( queryDB( msg ) )

	elseif TASKS[cmd] then
	    tasks:send_msg(urldecode(msg))

	elseif FEED[cmd] then feed(cmd, msg, msgr)

	elseif TABS[cmd] then tabs(msg, msgr) end

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

