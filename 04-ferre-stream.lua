#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local keys	  = require'carlos.fold'.keys
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

local WEEK 	  = { ticket=true, presupuesto=true } -- pagado 		

local FERRE 	  = { update=true, faltante=true }

local FEED 	  = { feed=true, ledger=true, adjust=true }

local INMEM 	  = { tabs=true, delete=true,
			pins=true, login=true, -- CACHE
			version=true, -- CACHE
			bixolon=true, uid=true,
			CACHE=true }

--------------------------------
-- Local function definitions --
--------------------------------
--

local function sendAll(skt, tag, msg)
    insert(msg, 1, tag)
    print( 'Sent to', tag, skt:send_msgs(msg), '\n' )
end

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

	if cmd == 'OK' then

	elseif id:match'app' then
	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if INMEM[cmd] then sendAll( stream, 'inmem', msg )

	    elseif WEEK[cmd] then sendAll( stream, 'weekdb', msg )

	    elseif FERRE[cmd] then sendAll( stream, 'ferredb', msg ) end

	elseif id:match'ferredb' then
	    print( 'Received from ferredb\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

	elseif id:match'weekdb' then
	    print( 'Received from weekdb\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

	end

end

--[[
		insert(msg, 1, 'inmem')
		print( 'Sent to inmem:', stream:send_msgs(msg), '\n' )

		insert(msg, 1, 'weekdb')
		print( 'Sent to weekdb:', stream:send_msgs(msg), '\n' )

		insert(msg, 1, 'ferredb')
		print( 'Sent to ferredb:', stream:send_msgs(msg), '\n' )

--]]
