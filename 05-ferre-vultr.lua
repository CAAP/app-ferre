#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local connect		= require'carlos.sqlite'.connect
local aspath		= require'carlos.ferre'.aspath

local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local keypair		= require'lzmq'.keypair
local dbconn		= require'carlos.ferre'.dbconn
local aspath		= require'carlos.ferre'.aspath
local asweek		= require'carlos.ferre'.asweek
local asJSON		= require'json'.encode
local fromJSON		= require'json'.decode

local format	= string.format
local tointeger = math.tointeger
local concat 	= table.concat
local unpack	= table.unpack
local date	= os.date
local tonumber  = tonumber
local tostring	= tostring
local assert	= assert
local pcall     = pcall
local exec	= os.execute
local exit	= os.exit
local time	= os.time

local pairs	= pairs

local print	= print

local WEEK	= asweek( time() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	 = 'ipc://stream.ipc'
local LEDGER	 = 'tcp://149.248.21.161:5610' -- 'vultr'
local SRVK	 = "YK&>B&}SK^8hF-P/3i^)JlB5mV0T4IJUYRhT{436"

local QTKTS	 = 'SELECT MAX(uid) uid FROM tickets'
local QVERS	 = 'SELECT MAX(vers) vers FROM updates'
local UVERS	 = 'SELECT * FROM datos WHERE clave IN (SELECT PRINTF("%%s", clave) FROM updates WHERE vers > %d GROUP BY clave)'

local vers	 = 0

local conn = assert( connect':inmemory:' )

--------------------------------
-- Local function definitions --
--------------------------------
--
local function receive(skt, a)
    return fd.reduce(function() return skt:msgs(true) end, fd.into, a)
end

local function plain(a) return asJSON(a) end

--[[
local function wired(w)
    local tag = w.tag
    return {tag, asJSON(w)}
end
--]]
local function switch(msg)
    local _, v, old = unpack(msg)

    if v == 'vers' then
	local q = format(UVERS, old)
	return fd.reduce(conn.query(q), fd.map(plain), fd.into, {'update', vers}) --  fd.map(wired)

    elseif v == 'uid' then
	local q = format('SELECT * FROM tickets WHERE uid > %q', old)
	return fd.reduce(conn.query(q), fd.map(plain), fd.into, {'ticket'}) --  fd.map(wired)
    end
end
---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local path = aspath'ferre'
assert( conn.exec(format('ATTACH DATABASE %q AS ferre', path)) )
assert( conn.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
assert( conn.exec'DETACH DATABASE ferre' )

assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(WEEK))) )
assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
assert( conn.exec'CREATE TABLE updates AS SELECT * FROM week.updates' )
assert( conn.exec'DETACH DATABASE week' )

print("ferre & week DBs was successfully open\n")

--vers = conn.count'updates' -- XXX select count(*) from (select distinct(clave) from updates)
vers = fd.first(conn.query( QVERS ), function(x) return x end).vers or 0
local uid = fd.first(conn.query( QTKTS ), function(x) return x end).uid or '0'

-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local www = assert(CTX:socket'DEALER')

assert( www:set_id'FA-BJ-01' )

assert( keypair():client(www, SRVK) )

assert( www:connect( LEDGER ) )

print('\nSuccessfully connected to:', LEDGER)
--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'DEALER')

assert( msgr:set_id'vultr' )

msgr:linger(0)

assert( msgr:connect( STREAM ) )

assert( msgr:send_msg'OK' )

print('\nSuccessfully connected to:', STREAM)
--
-- -- -- -- -- --
--
do
    local vv = asJSON{vers=vers, uid=uid}
    print(vv, '\n')
    www:send_msgs{'Hi', vv}
end
--
-- -- -- -- -- --
--
--
-- Run loop
--


print'+\n'

    pollin({www}, 3000)

    if www:events() == 'POLLIN' then

	local msg, more = www:recv_msg()
	local cmd = msg:match'%a+'

	if more then
	    msg = receive(www, {msg}) -- www:recv_msgs(true) -- 
	    print(concat(msg, '&'), '\n')
	else
	    print(msg, '\n')
	end
---[[
	if cmd == 'update' then
	    print('Recieving updates...', '\n')
	    msgr:send_msgs{'app', 'updatex', msg[2]} -- msg[1]
--]]
	elseif cmd == 'adjust' then
	    print('Sending adjust...', '\n')
	    local q = switch(msg)
	    www:send_msgs(q)
	end

    end


print'Shutting down\n'
exit(true, true)
