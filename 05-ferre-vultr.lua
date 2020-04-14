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
local date	= os.date
local tonumber  = tonumber
local tostring	= tostring
local assert	= assert
local pcall     = pcall

local pairs	= pairs

local print	= print

local WEEK	= asweek( os.time() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local LEDGER	 = 'tcp://149.248.21.161:5610' -- 'vultr'
local SRVK	 = "*dOG4ev0i<[2H(*GJC2e@6f.cC].$on)OZn{5q%3"

local QTKTS	 = 'SELECT MAX(uid) uid FROM tickets'
--------------------------------
-- Local function definitions --
--------------------------------
--
local function getVers(conn)
    local vers = conn.count'updates'
    local uid = fd.first(conn.query( QTKTS ), function(x) return x end).uid:sub(1,19)
    VERS = {vers=vers, uid=uid}
    return VERS
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local conn = assert( connect':inmemory:' )

local path = aspath'ferre'
assert( conn.exec(format('ATTACH DATABASE %q AS ferre', path)) )
assert( conn.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
assert( conn.exec'DETACH DATABASE ferre' )

assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(WEEK))) )
assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
assert( conn.exec'CREATE TABLE updates AS SELECT * FROM week.updates' )
assert( conn.exec'DETACH DATABASE week' )

print("ferre & week DBs was successfully open\n")

local vers = conn.count'updates'
local uid = fd.first(conn.query( QTKTS ), function(x) return x end).uid -- :sub(1,19)

print('vers:', vers, 'uid:', uid, '\n')
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local www = assert(CTX:socket'DEALER')

assert( www:immediate(true) )

assert( www:set_id'FA-BJ-01' )

assert( keypair():client(www, SRVK) )

assert( www:connect( LEDGER ) )

print('\nSuccessfully connected to:', LEDGER)
--
-- -- -- -- -- --
--

www:send_msgs{'Hi', asJSON{vers=vers, uid=uid}}

--
-- -- -- -- -- --
--
-- Run loop
--

while true do
print'+\n'

    pollin{www}

    local msg, more = www:recv_msg()
    local cmd = msg:match'%a+'
    local pid = msg:match'pid=(%d+)'

    if more then
	msg = receive(www, {msg})
	print(concat(msg, '&'), '\n')
    else
	print(msg, '\n')
    end

    if cmd == 'update' then
--	tasks:send_msgs{'weekdb', cmd, ret}

    elseif cmd == 'adjust' then

    elseif cmd == 'OK' then break end
end

