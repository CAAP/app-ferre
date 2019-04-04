#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local into		= require'carlos.sqlite'.into
local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local dbconn		= require'carlos.ferre'.dbconn
local asweek		= require'carlos.ferre'.asweek
local connexec		= require'carlos.ferre'.connexec
local receive		= require'carlos.ferre'.receive
local now		= require'carlos.ferre'.now
local asnum		= require'carlos.ferre'.asnum
local newTable    	= require'carlos.sqlite'.newTable
local ticket		= require'carlos.ticket'.ticket

local format	= string.format
local floor	= math.floor
local concat 	= table.concat
local remove	= table.remove
local open	= io.open
local date	= os.date
local assert	= assert

local pairs	= pairs

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7
local QUERIES	 = 'ipc://queries.ipc'
local ROOT	 = '/var/www/htdocs/app-ferre/caja/json'

local TABS	 = {tickets = 'uid, tag, prc, clave, desc, costol NUMBER, unidad, precio NUMBER, unitario NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'prc', 'clave', 'desc', 'costol', 'unidad', 'precio', 'unitario', 'qty', 'rea', 'totalCents'}
local PEOPLE	= {A = 'caja'} -- could use 'fruit' id instead XXX

local QRY	= 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUID	= 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag FROM tickets WHERE uid %s %q GROUP BY uid'
local QTKT	= 'SELECT uid, tag, clave, qty, rea, totalCents,  prc "precio" FROM tickets WHERE uid LIKE %q'
local QDESC	= 'SELECT desc FROM precios WHERE desc LIKE %q ORDER BY desc LIMIT 1'
local QHEAD	 = 'SELECT uid, tag, ROUND(SUM(totalCents)/100.0, 2) total from tickets WHERE uid LIKE %q GROUP BY uid'
local QLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, ROUND(totalCents/100.0, 2) subTotal FROM tickets WHERE uid LIKE %q'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function round(n, d) return floor(n*10^d+0.5)/10^d end

local function process(uid, tag, conn2)
    return function(q)
	local o = {uid=uid, tag=tag}
	for k,v in q:gmatch'([%a%d]+)|([^|]+)' do o[k] = asnum(v) end
	local lbl = 'u' .. o.precio:match'%d$'
	local rea = (100-o.rea)/100.0
	local b = fd.first(conn2.query(format(QRY, o.clave)), function(x) return x end)
	fd.reduce(fd.keys(o), fd.merge, b)
	b.precio = b[o.precio]; b.unidad = b[lbl];
	b.prc = o.precio; b.unitario = b.rea > 0 and round(b.precio*rea, 2) or b.precio
	return fd.reduce(INDEX, fd.map(function(k) return b[k] or '' end), fd.into, {})
    end
end

local function addTicket(conn, conn2, msg)
    local tag	    = msg:match'%a+'
    local data, uid = msg:match'&([^!]+)&uid=([^!]+)$'
    fd.reduce(fd.wrap(data:gmatch'query=([^&]+)'), fd.map(process(uid, tag, conn2)), into'tickets', conn)
    return uid
end

local function getName(o)
    local pid = asnum(o.uid:match'P([%d%a]+)')
    o.nombre = pid and PEOPLE[pid] or 'NaP';
    return o 
end

local function dumpFEED(conn, fruit, qry)
    local FIN = open(format('%s/%s-feed.json', ROOT, fruit), 'w')
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(qry), fd.map(getName), fd.map(asJSON), fd.into, {}), ',\n') )
    FIN:write']'
    FIN:close()
    return 'Updates stored and dumped'
end

local function byDesc(conn, s)
    local qry = format(QDESC, s:gsub('*', '%%')..'%%')
    local o = fd.first(conn.query(qry), function(x) return x end)
    return o.desc
end

local function byClave(conn, s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    return asJSON( fd.first(conn.query(qry), function(x) return x end) )
end

local function fields(a, t) return fd.reduce(a, fd.map(function(k) return t[k] end), fd.into, {}) end

local function bixolon(uid, conn)
    local HEAD = {'tag', 'uid', 'total', 'nombre'}
    local DATOS = {'clave', 'desc', 'qty', 'rea', 'unitario', 'subTotal'}

    local head = getName(fd.first(conn.query(format(QHEAD, '%.2f', uid)), function(x) return x end))

    local data = fd.reduce(conn.query(format(QLPR, '%.2f', '%.2f', uid)), fd.into, {})

    print( ticket(head, data) )
    return true
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local TODAY = asweek(now())

local PRECIOS = assert( dbconn'ferre' )

local WEEK = assert( dbconn( TODAY, true ) )

fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(WEEK, format(newTable, tbname, schema)) end)

print("ferre and this week DBs were successfully open\n")
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local queues = assert(CTX:socket'ROUTER')

assert(queues:bind( QUERIES ))

print('Successfully bound to:', QUERIES)
--
-- -- -- -- -- --
--
-- Store PEOPLE values
--
fd.reduce(PRECIOS.query'SELECT * FROM empleados', fd.rejig(function(o) return o.nombre, asnum(o.id) end), fd.merge, PEOPLE)
--
-- -- -- -- -- --
-- Run loop
--

local function which(week) return TODAY==week and WEEK or assert(dbconn( week )) end

while true do
print'+\n'
    pollin{queues}
    print'message received!\n'
    local id, msg = receive( queues )
    msg = msg[1]
    local cmd = msg:match'%a+'

    if cmd == 'ticket' or cmd == 'presupuesto' then
	local uid = addTicket(WEEK, PRECIOS, msg)
	local qry = format(QUID, 'LIKE', uid)
	local msg = asJSON(getName(fd.first(WEEK.query(qry), function(x) return x end)))
	queues:send_msgs{'WEEK', format('feed %s', msg)}
	bixolon(uid, WEEK)
	print(msg, '\n')
    elseif cmd == 'feed' then
	local fruit = msg:match'%s(%a+)' -- secs = %s(%d+)$
	local t = date('%FT%T', now()):sub(1, 10)
	local qry = format(QUID, '>', t)
	print(dumpFEED( WEEK, fruit, qry ), '\n')
	queues:send_msgs{'WEEK', format('%s feed %s-feed.json', fruit, fruit)}
    elseif cmd == 'query' then
	local fruit = msg:match'fruit=(%a+)'
	local ret
	if msg:match'desc' then
	    ret = msg:match'desc=([^!&]+)' -- potential error if '&' included
	    ret = byDesc(PRECIOS, ret)
	elseif msg:match'clave' then
	    ret = msg:match'clave=([%a%d]+)' -- potential error if '&' included
	    ret = byClave(PRECIOS, ret)
	end
	print('Querying database ...\n')
	queues:send_msgs{'WEEK', format('%s query %s', fruit, ret)}
    elseif cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local week   = msg:match'week=([^!&]+)'
	local qry   = format(QTKT, uid)
	print(dumpFEED( which(week), fruit, qry ), '\n') -- as shown in query, create fn 'byUID'
	queues:send_msgs{'WEEK', format('%s uid %s-feed.json', fruit, fruit)}
    elseif cmd == 'bixolon' then
	local uid, week = msg:match'%s([^!]+)%s([^!]+)'
	bixolon(uid, which(week))
	print('Printing data ...\n')
    elseif cmd == 'update' then
	print()
    end
end

--[[    
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'DB' then
	    queues:send_msgs{id, 'Bye DB'}
	    break
	end
    end
--]]

