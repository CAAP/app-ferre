#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local keys	  = require'carlos.fold'.keys
local receive	  = require'carlos.ferre'.receive
local newUID	  = require'carlos.ferre'.newUID
local asnum	  = require'carlos.ferre'.asnum
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
local type	  = type
local not	  = not

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

local UUID	 = {}

local CACHE	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function sendAll(skt, tag, msg)
    insert(msg, 1, tag)
    print( 'Sent to', tag, skt:send_msgs(msg), '\n' )
end

local function getUUID(msg, cmd, pid, uuid, M, N)
    if uuid then
	if not(UUID[uuid]) then
	    UUID[uuid] = newUID()..pid
	    CACHE[uuid] = {}
	end
	local uid = UUID[uuid]
	local w = CACHE[uuid]
	client:hset(uid, 'cmd', cmd, 'pid', pid)
	w[#w+1] = msg
	if M <= (#w * N) then
	    client:hset(uid, 'data', concat(CACHE[uuid], '&'))
	    UUID[uuid] = nil
	    CACHE[uuid] = nil
	    return uid
	else return {'uuid', uuid} end
    else
	local uid = newUID()..pid
	client:hset(uid, 'data', msg, 'pid', pid, 'cmd', cmd)
	return uid
    end
end

local function asUUID(msg)
    local pid = asnum(msg:match'pid=([%d%a]+)')
    local uuid = msg:match'uuid=(%w+)'
    local length = tointeger(msg:match'length=(%d+)')
    local size = tointeger(msg:match'size=(%d+)')
    local msg = msg:sub(msg:find'query=', -1) -- leaving only query=ITEM_1&query=ITEM_2&query=ITEM_3...
    return getUUID(msg, cmd, pid, uuid, length, size)
end

local function tabs(cmd, msg)
    local pid = msg[2]:match'pid=(%d+)' or msg[1]:match'pid=(%d+)'
    local ft = client:hget(MG, pid)

    if cmd == 'login' then
	local fruit = msg[2]:match'fruit=(%a+)'
	local ret = {}
	-- guard against double login by sending message to first session & closing it
	if ft and ft ~= fruit then ret[1] = format('%s logout pid=%d', ft, pid) end
	-- in any case
	client:hset(MG, pid, fruit) -- new session open
	if client:exists(pid) then
	    ret[#ret+1] = client:hexists(pid, 'msgs')
	    ret[#ret+1] = client:hexists(pid, 'tabs')
	end
	return ret -- returns a table | possibly empty

    -- store, short-circuit & re-route the message
    if cmd == 'msgs' then
	insert(msg, 1, '$FRUIT') -- placeholder for FRUIT
	insert(msg, '\n\n')
	client:hset(pid, 'msgs', concat(msg, ' ')) -- store msg
	if ft then -- is session open in any client?
	    return {client:hget(pid, 'msgs'):gsub('$FRUIT', ft)}
	end

    elseif cmd == 'tabs' then
	local uid = asUUID(msg[2])
	if uid then
	    local msg = format('$FRUIT pid=%d&%s\n\n', pid, client:hget(uid, 'data'))
	    client:hdel(uid)
	    client:hset(pid, 'tabs', msg)
	end
	return {': OK\n\n'}

    elseif cmd == 'delete' then
	client:hdel(pid, 'tabs')
	return {': OK\n\n'}

--    elseif cmd == 'CACHE' and client:hexists(pid, 'msgs') then
--	return client:hget(pid, 'msgs'):gsub('$FRUIT', ft)

    else
	print'\nERROR: Unknown command\n'
	return {': OK\n\n'}

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
	    stream:send_msgs( tabs(cmd, msg) )

	----------------------------------
	-- convert into MULTI-part msgs --
	----------------------------------
	elseif msg[2]:match'query=' then -- XXX ISTKT???
	    local uid = asUUID(msg[2])
	    if uid then stream:send_msgs{'db', 'uid', uid} end


-- XXX REST & MORE
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

