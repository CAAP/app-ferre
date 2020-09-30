#! /usr/bin/env lua53

-- Import Section
--
local tabs	  = require'carlos.ferre.tabs'
local asUUID	  = require'carlos.ferre.uuids'
local reduce	  = require'carlos.fold'.reduce
local receive	  = require'carlos.ferre'.receive
local posix	  = require'posix.signal'
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

local assert	  = assert
local exit	  = os.exit
local concat	  = table.concat
local insert	  = table.insert

local print	  = print
local type	  = type

local STREAM	  = os.getenv'STREAM_IPC'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local TABS	  = { tabs=true, delete=true,
		      msgs=true, login=true } -- , CACHE=true, pins=true

local WEEK 	  = { ticket=true, presupuesto=true } -- pagado 		

local FERRE 	  = { update=true, faltante=true }

local INMEM 	  = { version=true, bixolon=true,
		      uid=true,     feed=true,
		      ledger=true,  adjust=true } -- CACHE=true

--------------------------------
-- Local function definitions --
--------------------------------
--

local function sendAll(skt, tag, msg)
    insert(msg, 1, tag)
    print( 'Sent to', tag, skt:send_msgs(msg), '\n' )
end

local function broadcast(skt, msg)
    local msg = msg or ': OK\n\n'
    local N = 1
    if type(msg) == 'table' then
	reduce(msg, function(m) skt:send_msgs{'SSE', m} end)
	N = #msg
    else
	skt:send_msgs{'SSE', msg}
    end
    print( 'Broadcasting', N, 'message(s)\n\n+\n' )
end

---------------------------------
-- Program execution statement --
---------------------------------

local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
-- Initilize server(s)
local CTX = context()

local stream = assert(CTX:socket'ROUTER')

assert( stream:mandatory(true) ) -- causes error in case of unroutable peer

--assert( stream:linger(0) )

assert( stream:bind( STREAM ) )

print('\nSuccessfully bound to:', STREAM, '\n')
--
-- -- -- -- -- --
--[[
--]]
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream}

    if stream:events() == 'POLLIN' then

	local id, msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print(id, concat(msg, ' '), '\n')

	if cmd == 'OK' then

--	elseif cmd == 'SSE' then
--	    stream:send_msgs( msg )

	----------------------
	-- divide & conquer --
	----------------------
	elseif TABS[cmd]  then
	    broadcast( stream, tabs(cmd, msg) )

	----------------------------------
	-- convert into MULTI-part msgs --
	----------------------------------
	elseif msg[2]:match'query=' then -- XXX ISTKT???
	    local uuid = asUUID(msg[2])
	    if uuid then stream:send_msgs{'db', cmd, uuid} end


-- XXX REST & MORE
	elseif id:match'app' then
	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if INMEM[cmd] then sendAll( stream, 'inmem', msg )

	    elseif WEEK[cmd] then sendAll( stream, 'weekdb', msg )

	    elseif FERRE[cmd] then sendAll( stream, 'ferredb', msg ) end

	end

    end

end

