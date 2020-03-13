#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local urldecode   = require'carlos.ferre'.urldecode
local queryDB	  = require'carlos.ferre'.queryDB
local receive	  = require'carlos.ferre'.receive
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local assert	  = assert
local concat	  = table.concat
local insert	  = table.insert

local print	  = print

local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

local WEEK = { pagado=true, adjust=true } -- ticket, presupuesto

local FERRE = { update=true, faltante=true, query=true,
		ticket=true, presupuesto=true}

local FEED = { feed=true, ledger=true, uid=true } -- bixolon, msgs

local INMEM = { tabs=true, delete=true,
		pins=true, login=true,
		version=true,
		CACHE=true }

--------------------------------
-- Local function definitions --
--------------------------------
--

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local stream = assert(CTX:socket'ROUTER')

assert( stream:mandatory(true) ) -- causes error in case of unroutable peer

assert( stream:bind( STREAM ) )

print('\nSuccessfully bound to:', STREAM, '\n')
--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream}

	local id, msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print(id, concat(msg, '&'), '\n')

	if id:match'TASK' then
	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if INMEM[cmd] then
		insert(msg, 1, 'inmem')
		print( 'Sent to inmem:', stream:send_msgs(msg), '\n' )

	    elseif WEEK[cmd] then
		insert(msg, 1, 'weekdb')
		print( 'Sent to weekdb:', stream:send_msgs(msg), '\n' )

	    elseif FERRE[cmd] then
		insert(msg, 1, 'ferredb')
		print( 'Sent to ferredb:', stream:send_msgs(msg), '\n' )

	    end

	elseif id:match'ferredb' then
	    print( 'Received from ferredb\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

	elseif id:match'weekdb' then
	    print( 'Received from weekdb\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

	end

end
