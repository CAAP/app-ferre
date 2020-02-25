#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local urldecode   = require'carlos.ferre'.urldecode
local queryDB	  = require'carlos.ferre'.queryDB
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

local tabs	= require'carlos.ferre.tabs'
local vers	= require'carlos.ferre.vers'
local feed	= require'carlos.ferre.feed'

local assert	  = assert
local concat	  = table.concat

local print	  = print

local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc' --  
--local DOWNSTREAM = 'tcp://*:5050' -- 
local UPSTREAM   = 'ipc://upstream.ipc'
--local UPSTREAM	 = 'tcp://localhost:5060'
local DBSTREAM	 = 'ipc://dbstream.ipc'

local TASKS = { ticket=true, presupuesto=true,
		update=true, bixolon=true,
		pagado=true, faltante=true }

local FEED = { feed=true, ledger=true, uid=true }

local TABS = {  tabs=true, delete=true, msgs=true,
		pins=true, login=true, CACHE=true }

local VERS = {  adjust=true, version=true, CACHE=true }

--------------------------------
-- Local function definitions --
--------------------------------
--

--local function receive(skt) return concat(skt:recv_msgs(), ' ') end

local function hub(msg, tasks, msgr)
	----------------------
	-- divide & conquer --
	local cmd = msg:match'%a+'

	if cmd == 'query' then
	    msgr:send_msg( queryDB( msg ) )

	elseif TASKS[cmd] or (cmd == 'adjust' and msg:match( WEEK )) then
	    tasks:send_msg(urldecode(msg))

	elseif FEED[cmd] then feed(msg, msgr) end

	if TABS[cmd] then tabs(msg, msgr) end -- because of CACHE

	if VERS[cmd] then vers(msg, msgr) end -- because of CACHE

	return msg -- msg:match'([^%c]+)%c'
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'PULL')

assert(server:connect( DOWNSTREAM ))

print('Successfully connected to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')
--- -- -- -- -- --
--
local tasks = assert(CTX:socket'PUSH')

assert( tasks:immediate(true) ) -- queue outgoing to completed connections only

assert( tasks:connect( DBSTREAM ) )

print('\nSuccessfully connected to:', DBSTREAM, '\n')
-- -- -- -- -- --
--

while true do

    print'+\n'

    if pollin{server} then

	if server:events() == 'POLLIN' then

	    local msg = server:recv_msg()

	    print( hub(msg, tasks, msgr), '\n' )

	end

    end

end
