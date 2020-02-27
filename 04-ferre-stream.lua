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

local print	  = print

local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

local WEEK = { ticket=true, presupuesto=true,
		pagado=true }

local FERRE = { update=true, faltante=true }

local FEED = { feed=true, ledger=true, uid=true }

local INMEM = { tabs=true, delete=true, msgs=true,
		pins=true, login=true,
		adjust=true, version=true,
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

--[[ -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')
--]] -- -- -- -- --
--

--
-- -- -- -- -- --
--

--
-- -- -- -- -- --
--

while true do
    print'+\n'

    pollin{stream}

    local id, msg = receive( stream )
	msg = concat(msg, ' ')
	print(id, msg, '\n')

	if id:match'TASK' then
	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    local cmd = msg:match'%a+'

	    if INMEM[cmd] then
		print( stream:send_msgs{'inmem', msg} )

	    elseif WEEK[cmd] then
		stream:send_msgs{'week', msg}

	    end

	end

end
