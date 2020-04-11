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

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local LEDGER	 = 'tcp://149.248.21.161:5610' -- 'vultr'
local SRVK	 = "*dOG4ev0i<[2H(*GJC2e@6f.cC].$on)OZn{5q%3"

local QDESC	 = 'SELECT clave FROM precios WHERE desc LIKE %q ORDER BY desc LIMIT 1'

--------------------------------
-- Local function definitions --
--------------------------------
--

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

assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(week))) )
assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
assert( conn.exec'CREATE TABLE updates AS SELECT * FROM week.updates' )
assert( conn.exec'DETACH DATABASE week' )

print("ferre & week DBs was successfully open\n")
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

www:send_msg'OK'

--
-- -- -- -- -- --
--
-- Run loop
--

while true do
print'+\n'

    pollin{tasks}

    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    print(msg, '\n')

    if cmd == 'update' then
	local w = fromJSON( msg:match'{[^}]+}' )
	local fruit = w.fruit
	local ret = asJSON( addUpdate(PRECIOS, w) )
	tasks:send_msgs{'weekdb', cmd, ret}
--]]

--	www:send_msg( msg ) -- WWW


    elseif cmd == 'faltante' then
	print( msg )

    end
end



