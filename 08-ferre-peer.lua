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

    if cmd == 'ticketx' then
--[[	    
	msg[1] = TIENDA
	local uid = msg[2]
	local k = QTKT..uid
	reduce(client:lrange(k, 0, -1), into, msg)
	return true
--]]
    elseif cmd == 'updatex' then
	msg[1] = TIENDA
	return true

    elseif cmd:match'FA-' then
	if msg[2]:match'%d+%-%d+%-%d+T' then 	-- ticket
	    local uid = msg[2]
	    local k = QTKT..uid
	    reduce(client:lrange(k, 0, -1), into, msg)
	end
	return true

    else
	return false

    end
end

local function process(msg)
    if msg[1]:match'FA%-BJ' then -- BJ | MX

	if msg[2]:match'%d+%-%d+%-%d+T' then 	-- ticket
--[[		
	    local uid = msg[2]
	    local SC = uid:match':(%d+)$'
	    local u = client:get('app:tickets:FA-BJ-'..SC) or '0x0x'..SC

	    if #msg == 2 then -- query
		if uid < u then
		    return {'inmem', 'queryx', unpack(msg)}
		else goto OK end

	    else -- new ticket

		if msg[3] == u then -- consecutive
		    local k = QTKT..uid
		    drop(3, msg, function(s) client:rpush(k, s) end)
		    client:expire(k, 120)
		    return {'DB', 'ticketx', uid}

	        elseif uid == u then goto OK -- already registered
		elseif uid > u then return {'peer', TIENDA, u} end -- help
		-- XXX what about uid < u ???
	    end
--]]
	else 					-- vers
	    local vers = msg[2]
	    local v = client:get'app:updates:version' or 0

	    if #msg == 2 then -- query
		if vers < v then
		    return {'inmem', 'queryx', unpack(msg)}
		else goto OK end

	    else -- new update
		local clave = msg[4]
		local Q = msg[#msg]
		local v = client:get'app:updates:version' or 0 -- send a ZERO if nothing updated XXX

		if msg[3] == v then -- consecutive
		    local qs = deserialize( Q:match"'%([^']+)'%)$" )
		    local k = 'queue:uuids:'..clave
		    client:rpush(k, unpack(qs))
		    client:expire(k, 120)
		    return {'DB', 'updatex', clave, vers}

		elseif vers == v then goto OK -- already registered
		elseif vers > v then return {'peer', TIENDA, v} end -- help

	    end

	end

    else -- ???
print('Error:', msg[1], '\n')
    end

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

assert( msgr:timeout(1000) )

assert( keypair():client(msgr, TOKK) )

assert( msgr:connect( TOK ) )

print('\nSuccessfully connected to', TOK, '\n')

--
-- -- -- -- -- --
--

local msgs = assert(CTX:socket'SUB')

assert( msgs:linger(0) )

assert( msgr:timeout(1000) )

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

	if switch(msg) then
	    msgr:send_msgs( msg )
	end


    elseif msgs:events() == 'POLLIN' then

	local msg = msgs:recv_msgs()

	print('\nTIK:', concat(msg, ' '), '\n')

	stream:send_msgs( process(msg) )

    end

end

