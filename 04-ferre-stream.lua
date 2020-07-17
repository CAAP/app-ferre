#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local keys	  = require'carlos.fold'.keys
local receive	  = require'carlos.ferre'.receive
local posix	  = require'posix.signal'
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local keypair	  = require'lzmq'.keypair
local mgr	  = require'lmg'

local assert	  = assert
local exit	  = os.exit
local concat	  = table.concat
local insert	  = table.insert
local env	  = os.getenv

local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	  = env'STREAM_IPC'
local SSETCP	  = env'SSE_TCP'
local LEDGER	  = env'LEDGER'
local SRVK	  = "YK&>B&}SK^8hF-P/3i^)JlB5mV0T4IJUYRhT{436"

local WEEK 	  = { ticket=true, presupuesto=true } -- pagado 		

local FERRE 	  = { update=true, faltante=true }

local INMEM 	  = { tabs=true, delete=true, msgs=true,
			pins=true, login=true, -- CACHE
			version=true, -- CACHE
			bixolon=true,
			uid=true, feed=true, ledger=true,
			adjust=true,
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
--

local www = assert(CTX:socket'DEALER')

assert( www:set_id'FA-CA-01' )

assert( keypair():client(www, SRVK) )

assert( www:connect( LEDGER ) )

www:send_msg'OK'

print('\nSuccessfully connected to:', LEDGER)

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream, www}

    if stream:events() == 'POLLIN' then

	local id, msg = receive( stream )
	local cmd = msg[1]:match'%a+'

	print(id, concat(msg, ' '), '\n')

	if cmd == 'OK' then

	elseif cmd == 'SSE' then
	    stream:send_msgs( msg )

	elseif cmd == 'updatew' or 'Hiw' then
	    www:send_msgs( msg )

	elseif id:match'SSE' then
	    print( 'Received from SSE\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

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

	elseif id:match'vultr' then
	    print( 'Received from', id, '\n' )
	    print( 'Re-routed to', cmd, stream:send_msgs(msg), '\n' )

	end

    end

    if www:events() == 'POLLIN' then
	local msg = www:recv_msgs(true)
	local cmd = msg[1]:match'%a+'

	print(concat(msg, ' '), '\n')
	print( 'Received from LEDGER\n' )

	if cmd == 'update' then
	    print( 'Re-routed to', 'app', stream:send_msgs{'app', 'updatex', msg[2]}, '\n' )

	end

    end

end

