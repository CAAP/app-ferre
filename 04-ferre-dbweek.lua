#! /usr/bin/env lua

-- Import Section
--
local fd		= require'carlos.fold'

local into		= require'carlos.sqlite'.into
local asJSON		= require'json'.encode
local fromJSON		= require'json'.decode
local split		= require'carlos.string'.split
local countN		= require'carlos.string'.count
local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local keypair		= require'lzmq'.keypair
local dbconn		= require'carlos.ferre'.dbconn
local asweek		= require'carlos.ferre'.asweek
local connexec		= require'carlos.ferre'.connexec
local now		= require'carlos.ferre'.now
local uid2week		= require'carlos.ferre'.uid2week
local asnum		= require'carlos.ferre'.asnum
local asdata		= require'carlos.ferre'.asdata
local newTable    	= require'carlos.sqlite'.newTable
local ticket		= require'carlos.ticket'.ticket

local format	= string.format
local floor	= math.floor
local tointeger = math.tointeger
local concat 	= table.concat
local remove	= table.remove
local insert	= table.insert
local open	= io.open
local popen	= io.popen
local date	= os.date
local exec	= os.execute

local tonumber  = tonumber
local tostring	= tostring
local assert	= assert
local pcall     = pcall
local pairs	= pairs
local ipairs	= ipairs
local type	= type

local print	= print

local stdout	= io.stdout

local APP	= require'carlos.ferre'.APP

local PATH	= require'carlos.ferre'.HOME .. '/json/version.json'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
--local HOY	 = date('%d-%b-%y', now())
local PRINTER	 = 'nc -N 192.168.3.21 9100'

local STREAM = 'ipc://stream.ipc'
-- 'tcp://192.168.3.100:5050' -- 
local UPSTREAM   = 'ipc://upstream.ipc'
-- 'tcp://192.168.3.100:5060' -- 

local LEDGER	 = 'tcp://149.248.21.161:5610' -- 'vultr'
local SRVK	 = "*dOG4ev0i<[2H(*GJC2e@6f.cC].$on)OZn{5q%3"

local SUBS	 = { 'ticket', 'presupuesto', 'update', 'bixolon', 'pagado', 'adjust', 'faltante' }

local TABS	 = {tickets = 'uid, tag, prc, clave, desc, costol NUMBER, unidad, precio NUMBER, unitario NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER, uidSAT, nombre',
		   updates = 'vers INTEGER PRIMARY KEY, clave, msg', -- campo, valor
	   	   facturas = 'uid, fapi PRIMARY KEY NOT NULL, rfc NOT NULL, sat NOT NULL'}

local INDEX = fd.reduce(split(TABS.tickets, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})

--local QRY	 = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag FROM tickets WHERE tag NOT LIKE "factura" AND uid %s %q GROUP BY uid'
local CLAUSE	 = 'WHERE tag NOT LIKE "factura" AND uid %s %q'
local QTKT	 = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'
local QHEAD	 = 'SELECT uid, tag, ROUND(SUM(totalCents)/100.0, 2) total from tickets WHERE uid LIKE %q GROUP BY uid'
local QLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal FROM tickets WHERE uid LIKE %q'
local QPAY	 =  'UPDATE tickets SET tag = "pagado" WHERE uid LIKE %q' 

local DIRTY	 = {clave=true, tbname=true, fruit=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local MEM	 = {}
local VERS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function dumpit(v)
    exec(format('%s/dump-price.lua', APP))
    dump(PATH, v)
end

local function receive(skt, a) return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a) end

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat2(clave, n)
    clave = tointeger(clave) or format('%q', clave) -- "'%s'"
    return function(v, k)
	n = n + 1
	local vv = smart(v, k)
	local ret = {n, clave, k, vv}
	return ret
    end
end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function addTicket(conn, msg)
    remove(msg, 1)

    if #msg > 6 then
	fd.slice(5, msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    else
	fd.reduce(msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    end
    return fromJSON(msg[1]).uid
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local TODAY = asweek(now())

local WEEK = assert( dbconn( TODAY, true ) )

fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(WEEK, format(newTable, tbname, schema)) end)

print("this week DB was successfully open\n")
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'weekdb' )

assert(tasks:connect( STREAM ))

print('\nSuccessfully connected to:', STREAM)
--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate( true ) )

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM)
--
--[[ -- -- -- -- --
--
local www = assert(CTX:socket'REQ')

assert( www:set_id'FA-BJ-01' )

assert( keypair():client(www, SRVK) )

assert( www:connect( LEDGER ) )

print('\nSuccessfully connected to:', LEDGER, '\n')
--
--]] -- -- -- -- --
--
-- Store PEOPLE values
--
-- -- -- -- -- --
--

tasks:send_msg'OK'

--
-- Run loop
--

local k = 0

while true do
print'+\n'

    pollin{tasks}

    local msg, more = tasks:recv_msg()
    local cmd = msg:match'%a+'

    if cmd == 'OK' then end

    if more then
	msg = receive(tasks, {msg})
	print(concat(msg, '&'), '\n')
    else
	print(msg, '\n')
    end

    if cmd == 'ticket' or cmd == 'presupuesto' or cmd == 'pagado' then
	local uid = addTicket(WEEK, msg)
	insert(msg, 1, 'ticket')
	insert(msg, 1, 'inmem')
	tasks:send_msgs(msg)

	print( 'UID:', uid, '\n' )

    elseif cmd == 'update' then -- msg from 'ferredb' to be re-routed to 'inmem'
	local u = WEEK.count'updates' + 1
	local w = fromJSON( msg[2] )
	local clave = tointeger(w.clave) or format('%q', w.clave)
	local fruit = w.fruit

	w.store = 'PRICE'; w.tbname = nil; w.fruit = nil;

	local msg = asJSON{w, {vers=u, week=TODAY, store='VERS'}}
	local q = format("INSERT INTO updates VALUES (%d, %s, '%s')", u, clave, msg)
	assert( WEEK.exec( q ) )

	local v = asJSON{vers=u, week=TODAY}
	tasks:send_msgs{'inmem', cmd, q, v}

	print( 'vers:', u, '\n' )

	k = k+1
	if k%10 == 0 then dumpit(v) end
    end

end

--[[
    if cmd == 'pagado' and msg:match'uid' then
	local uid = msg:match'uid=([^!]+)'
--	uid:match'HOY' must be TRUE
	pcall(WEEK.exec(format(QPAY, uid)))
	local qry = format(QUID, 'LIKE', uid)
	local m = jsonName(fd.first(WEEK.query(qry), function(x) return x end))
	msgr:send_msg(format('feed %s', m))
--	www:send_msg( msg ) -- WWW
--]]
