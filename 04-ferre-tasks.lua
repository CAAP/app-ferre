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
local pollin	  = require'lzmq'.pollin
local asJSON	  = require'carlos.json'.asJSON

local tabs	= require'carlos.ferre.tabs'
local vers	= require'carlos.ferre.vers'

local assert	  = assert
local exec	  = os.execute
local format	  = string.format
local concat	  = table.concat
local format	  = string.format

local print	  = print

local APP	  = require'carlos.ferre'.APP

local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc' --  
--local DOWNSTREAM = 'tcp://*:5050' -- 
local OK	 = response{status='ok'}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function handshake(server, tasks, msgr)
    local id, msg = receive(server)
    msg = distill(msg)
    if msg then
	-- send OK  & close socket
	send(server, id, OK)
	send(server, id, '')
	----------------------
	-- divide & conquer --
	local cmd = msg:match'%a+'

	if cmd == 'query' then
	    msgr:send_msg( queryDB( msg ) )

	elseif TASKS[cmd] or (cmd == 'adjust' and msg:match( WEEK )) then
	    tasks:send_msg(urldecode(msg))

	elseif FEED[cmd] then feed(cmd, msg, msgr) end

	if TABS[cmd] then tabs(msg, msgr) end -- because of CACHE

	if VERS[cmd] then vers(msg, msgr) end -- because of CACHE

	return msg -- msg:match'([^%c]+)%c'
    else
	return 'Received empty message ;-('
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'DEALER')

assert( server:immediate(true) ) -- queue to completed connections only

assert(server:connect( DOWNSTREAM ))

print('Successfully connected to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--

while true do

    print'+\n'

    if pollin{server} then

	if tasks:events() == 'POLLIN' then


	end

    end

end
