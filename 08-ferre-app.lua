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
local redis	  = require'redis'

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

local TABS	  = { tabs=true, delete=true, msgs=true,
			login=true, CACHE=true } -- pins=true


local client	  = assert( redis.connect('127.0.0.1', '6379') )

local MG	 = 'mgconn:active'



local WEEK 	  = { ticket=true, presupuesto=true } -- pagado 		

local FERRE 	  = { update=true, faltante=true }

local INMEM 	  = {   version=true,
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

local function switch(cmd, msg)
    local pid = msg[2]:match'pid=(%d+)' or msg[1]:match'pid=(%d+)'
    local ft = client:hget(MG, pid)

    if cmd == 'login' then
	local fruit = msg[2]:match'fruit=(%a+)'
	local ret = {}
	-- guard against double login by sending message to first session & closing it
	if ft and ft ~= fruit then ret[1] = format('%s logout pid=%d', ft, pid) end
	-- in any case
	client:hset(MG, pid, fruit)
	client:hset(fruit, 'pid', pid) -- new session opened & saved
	ret[#ret+1] = join(TABS.has(pid), fruit) -- tabs data, if any
	return ret -- returns a table | possibly empty


    -- store, short-circuit & re-route the message
    if cmd == 'msgs' then
	assert( client:exists(ft) )
	client:hset(ft, 'msgs', msg) -- store msg
	if ft then
	    insert(msg, 1, ft)
	    return concat(msg, ' ')
	end

    else -- tabs, delete

    end
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

	elseif cmd == 'SSE' then
	    stream:send_msgs( msg )

	    ----------------------
	    -- divide & conquer --
	    ----------------------

	elseif TABS[cmd]  then
	   tabs(cmd, msg, client)



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

end

