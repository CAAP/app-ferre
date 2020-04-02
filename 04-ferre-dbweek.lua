#! /usr/bin/env lua53

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
local dump		= require'carlos.files'.dump

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

local HOME	= require'carlos.ferre'.HOME
local APP	= require'carlos.ferre'.APP

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
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor',
	   	   facturas = 'uid, fapi PRIMARY KEY NOT NULL, rfc NOT NULL, sat NOT NULL'}

local INDEX = fd.reduce(split(TABS.tickets, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})

local PEOPLE	 = {A = 'caja'} -- could use 'fruit' id instead XXX

--local QRY	 = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag FROM tickets WHERE tag NOT LIKE "factura" AND uid %s %q GROUP BY uid'
local CLAUSE	 = 'WHERE tag NOT LIKE "factura" AND uid %s %q'
local QTKT	 = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'
local QHEAD	 = 'SELECT uid, tag, ROUND(SUM(totalCents)/100.0, 2) total from tickets WHERE uid LIKE %q GROUP BY uid'
local QLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal FROM tickets WHERE uid LIKE %q'
local QPAY	 =  'UPDATE tickets SET tag = "pagado" WHERE uid LIKE %q' 

local DIRTY	 = {clave=true, tbname=true, fruit=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local FRUIT	 = HOME .. '/ventas/json'

local MEM	 = {}
local VERS	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function receive(skt, a) return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a) end

local function round(n, d) return floor(n*10^d+0.5)/10^d end

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

local function addName(o)
    local pid = asnum(o.uid:match'P([%d%a]+)')
    o.nombre = pid and PEOPLE[pid] or 'NaP';
    return o
end

local function addTicket(conn, msg)
    remove(msg, 1)

    if #msg > 6 then
	fd.slice(5, msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    else
	fd.reduce(msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    end
    return fromJSON(msg[1]).uid
end

--local function jsonName(o) return asJSON(addName(o)) end

local function toCents(w)
    if w.total then w.total = format('%.2f', w.total) end
    return w
end

local function dumpFEED(conn, path, qry, clause) -- XXX correct FIN json
    if clause and conn.count( 'tickets', clause ) == 0 then return false end
    dump(path, asJSON(fd.reduce(conn.query(qry), fd.map(toCents), fd.map(addName), fd.into, {})))
    return true
end

local function dumpFRUIT(conn, vers, week)
    if #VERS > 500 then VERS,MEM = {},{} end

    if #VERS == 0 then goto EMPTY end

    if MEM[vers] then
	if vers == VERS[#VERS] then return MEM[vers] else
	return fd.reduce(VERS, fd.filter(function(w) return w>vers end), fd.map(function(w) return MEM[w]  end), fd.into, {}) end

    else
	if vers < VERS[1] then
	    local clause = format('WHERE vers > %d AND vers < %d', vers, VERS[1])
	    insert(VERS, 1, vers)
	    MEM[vers] = asJSON(asdata(conn, clause, week))
	    return dumpFRUIT(conn, vers, week, fruit)

	elseif vers > VERS[#VERS] then goto EMPTY

	else return 'OK' end

    end

::EMPTY::
    local clause = vers > 0 and format('WHERE vers > %d', vers) or ''
    local ret = asJSON(asdata(conn, clause, week))
    VERS[#VERS+1] = vers
    MEM[vers] = ret
    return ret

end

local function fields(a, t) return fd.reduce(a, fd.map(function(k) return t[k] end), fd.into, {}) end

local function bixolon(uid, conn)
    local HEAD = {'tag', 'uid', 'total', 'nombre'}
    local DATOS = {'clave', 'desc', 'qty', 'rea', 'unitario', 'subTotal'}

    local head = addName(fd.first(conn.query(format(QHEAD, uid)), function(x) return x end))

    local data = ticket(head, fd.reduce(conn.query(format(QLPR, uid)), fd.into, {}))

    local skt = popen(PRINTER, 'w') -- stdout -- 
    if #data > 8 then
	data = fd.slice(4, data, fd.into, {})
	fd.reduce(data, function(v) skt:write(concat(v,'\n'), '\n') end)
    else
	skt:write( concat(data,'\n') )
    end
    skt:close()

    return true
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
do
    local people = assert( dbconn'personas' )
    fd.reduce(people.query'SELECT * FROM empleados', fd.rejig(function(o) return o.nombre, asnum(o.id) end), fd.merge, PEOPLE)
end
--
-- -- -- -- -- --
--

tasks:send_msg'OK'

--
-- Run loop
--

local function which(week) return TODAY==week and WEEK or assert(dbconn( week )) end

local function send(fruit, ret) msgr:send_msg(format('%s adjust %s', fruit, ret)) end


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
--[[	
	local qry = format(QUID, 'LIKE', uid)
	local m = fd.first(WEEK.query(qry), function(x) return x end) -- jsonName()
	tasks:send_msgs{'inmem', 'feed', asJSON(m)}

	local qry = format(QUID, 'LIKE', uid)
	bixolon(uid, WEEK)
	www:send_msg( msg ) -- WWW
--]]

    elseif cmd == 'update' then -- msg from 'ferredb' to be re-routed to 'inmem'
	local u = WEEK.count'updates'
	local w = fromJSON( msg[2] )
	fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat2(w.clave, u)), into'updates', WEEK)
	tasks:send_msgs{'inmem', cmd, asJSON{vers=WEEK.count'updates', week=TODAY}}

    end

end

--[[

    elseif cmd == 'adjust' then
	local vers = asnum(msg:match'vers=(%d+)')
	local fruit = msg:match'fruit=(%a+)'
	local week = msg:match'week=([^!&]+)'
	-- week is THIS WEEK
	local ret = dumpFRUIT(WEEK, vers, week)
	if type(ret) == 'table' then
	    fd.reduce(fruit, ret, send)
	elseif ret ~= 'OK' then send(fruit, ret)
	else print"'adjust' not OK!\n" end

    if cmd == 'pagado' and msg:match'uid' then
	local uid = msg:match'uid=([^!]+)'
--	uid:match'HOY' must be TRUE
	pcall(WEEK.exec(format(QPAY, uid)))
	local qry = format(QUID, 'LIKE', uid)
	local m = jsonName(fd.first(WEEK.query(qry), function(x) return x end))
	msgr:send_msg(format('feed %s', m))
--	www:send_msg( msg ) -- WWW

    elseif cmd == 'bixolon' then -- XXX should prefer similar to adjust
	local uid = msg:match'uid=([^!]+)'
--	local uid = msg:match'%s([^!]+)'
	local week = uid2week( uid )
	bixolon(uid, which(week))
	print('Printing data ...\n')

--]]
