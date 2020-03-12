#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local into	  = require'carlos.fold'.into
local urldecode   = require'carlos.ferre'.urldecode
local queryDB	  = require'carlos.ferre'.queryDB
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local assert	  = assert
local concat	  = table.concat

local print	  = print

--local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM  = 'ipc://downstream.ipc' --  
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function receive(skt, a)
    return reduce(function() return skt:recv_msgs(true) end, into, a)
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

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'TASKS01' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

--[[ -- -- -- -- --
--

local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')

--
--]] -- -- -- -- --
--

tasks:send_msg'OK'

while true do
print'+\n'

    pollin{server}

	    local msg, more = server:recv_msg()
	    local cmd = msg:match'%a+'

	    if more then
		msg = receive(server, {msg})
		print(concat(msg, '&'), '\n')
	    else
		print(msg, '\n')
	    end

	    ----------------------
	    -- divide & conquer --
--	    if cmd == 'query' then
--	        msgr:send_msg( queryDB( msg ) )

	    if cmd == 'bixolon' then

	    else -- ticket, presupuesto & tabs are multi-part msgs
		if more then tasks:send_msgs( msg )
		else tasks:send_msg( msg ) end

	    end

end
