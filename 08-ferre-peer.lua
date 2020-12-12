#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local into	  = require'carlos.fold'.into
local drop	  = require'carlos.fold'.drop
local receive	  = require'carlos.ferre'.receive
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local keypair	  = require'lzmq'.keypair
local sleep	  = require'lbsd'.sleep
local b64	  = require'lints'.fromB64
local dN	  = require'binser'.dN

local rconnect	  = require'redis'.connect
local posix	  = require'posix.signal'

local assert	  = assert
local exit	  = os.exit
local concat	  = table.concat
local insert	  = table.insert
local remove	  = table.remove
local unpack	  = table.unpack
local format	  = string.format
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'
local REDIS	  = os.getenv'REDISC'
local TIENDA	  = os.getenv'TIENDA'
local TOK	  = os.getenv'TOK_TCP'
local TIK	  = os.getenv'TIK_TCP'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	  = assert( rconnect(REDIS, '6379') )

local TOKK	  = "{GLG5P!n{nler*9rX?e/E8}nxHRV5zu-huLa%A[3"
local TIKK	  = "xl[{Y243Pwa3?9IGx!SL6p>tg.-{*22-?g8v4/$z"


local QTKT	  = 'queue:tickets:'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function deserialize(s)
    local a,i = dN(b64(s), 1)
    return a
end

local function switch(msg)
    local cmd = msg[1]

    msg[1] = TIENDA

    if cmd == 'ticketx' then
	local uid = msg[2]
	local k = QTKT..uid
	reduce(client:lrange(k, 0, -1), into, msg)
	return true

    elseif cmd == 'updatex' then
	return true

    elseif cmd:match'FA-' then
	return true

    else
	return false

    end
end

local function process(msg)
    local cmd = msg[1]

    if cmd == TIENDA then

	if msg[2]:match'%d+%-%d+%-%dT' then 	-- ticket
	    if #msg == 2 then goto OK
	    else
		    -- cmd == 'ticketx'


	    end
	else 					-- vers
	    if #msg == 2 then goto OK
	    else
		goto OK
		    -- XXX cmd == 'updatex'
	    end

	end

    end

    if cmd:match'FA-' then -- BJ | MX

	if msg[2]:match'%d+%-%d+%-%dT' then 	-- ticket
	    local uid = msg[2]
	    local SC = uid:match':(%d+)$'
-- XXX		sleep(1500) -- wait
	    local u = client:get('app:tickets:FA-BJ-'..SC) or '0'

	    if #msg == 2 then -- query
		if uid <= u then
		    return {'inmem', 'xxx', uid}
		else goto OK end

	    else -- new ticket
		if msg[3] == u then -- consecutive
		    local k = QTKT..uid
		    fd.drop(3, msg, function(s) client:rpush(k, s) end)
		    client:expire(k, 120)
		    return {'DB', cmd, uid}
	        elseif uid == u then goto OK -- already registered
		elseif uid > u then return {'peer', TIENDA, u} end -- help
		-- XXX what about uid < u ???
	    end

	else 					-- vers
	    local vers = msg[2]
	    local v = client:get'app:updates:version' or 0

	    if #msg == 2 then -- query
		if vers < v then
		    return {'inmem', 'queries', vers}
		else goto OK end

	    else -- new update
	    end

	end

    else -- ???

    end



--[[
    elseif cmd == 'updatex' then
	sleep(1500) -- wait for pending updates

	local vers = msg[3]
	local overs = msg[4]
	local v = client:get'app:updates:version' or 0 -- send a ZERO if nothing updated XXX

	if overs == v then
	    local clave = msg[2]
	    local Q = msg[#msg]
	    local qs = deserialize( Q:match"'%([^']+)'%)$" )
	    local k = 'queue:uuids:'..clave
	    client:rpush(k, unpack(qs))
	    client:expire(k, 120)
	    return {'DB', cmd, clave, vers}

	elseif vers == v then goto OK

	else return {'peer', TIENDA, v} end

    end
--]]

    ::OK::
    return {'OK'}

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
--
local CTX = context()

local stream = assert(CTX:socket'DEALER')

assert( stream:immediate(true) )

assert( stream:linger(0) )

assert( stream:set_id('peer') )

assert( stream:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

stream:send_msg'OK'

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUB')

assert( msgr:linger(0) )

assert( keypair():client(msgr, TOKK) )

assert( msgr:connect( TOK ) )

print('\nSuccessfully connected to', TOK, '\n')

--
-- -- -- -- -- --
--

local msgs = assert(CTX:socket'SUB')

assert( msgs:linger(0) )

assert( msgs:subscribe'' )

assert( keypair():client(msgs, TIKK) )

assert( msgs:connect( TIK ) )

print('\nSuccessfully connected to', TIK, '\n')

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{stream, msgs}

    if stream:events() == 'POLLIN' then

	local msg = stream:recv_msgs()

	print('stream:', concat(msg, ' '), '\n')

--	if switch(msg) then
--	    msgr:send_msgs( msg )
--	end


    elseif msgs:events() == 'POLLIN' then

	local msg = msgs:recv_msgs()

	print('\nTIK:', concat(msg, ' '), '\n')

--	stream:send_msgs( process(msg) )

    end

end

