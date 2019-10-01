#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local into		= require'carlos.sqlite'.into
local asJSON		= require'json'.encode
local split		= require'carlos.string'.split
local countN		= require'carlos.string'.count
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

local print	= print

local stdout	= io.stdout

local HOME	= require'carlos.ferre'.HOME
local APP	= require'carlos.ferre'.APP

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7
local HOY	 = date('%d-%b-%y', now())
local QUERIES	 = 'ipc://queries.ipc'
local PRINTER	 = 'nc -N 192.168.3.21 9100'

local TABS	 = {tickets = 'uid, tag, prc, clave, desc, costol NUMBER, unidad, precio NUMBER, unitario NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER, uidSAT',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor',
	   	   facturas = 'uid, fapi PRIMARY KEY NOT NULL, rfc NOT NULL, sat NOT NULL'}

--local INDEX	 = {'uid', 'tag', 'prc', 'clave', 'uidSAT', 'desc', 'costol', 'unidad', 'precio', 'unitario', 'qty', 'rea', 'totalCents'}
local INDEX = fd.reduce(split(TABS.tickets, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})

local PEOPLE	 = {A = 'caja'} -- could use 'fruit' id instead XXX

local QRY	 = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag FROM tickets WHERE tag NOT LIKE "factura" AND uid %s %q GROUP BY uid'
local CLAUSE	 = 'WHERE tag NOT LIKE "factura" AND uid %s %q'
local QTKT	 = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'
local QHEAD	 = 'SELECT uid, tag, ROUND(SUM(totalCents)/100.0, 2) total from tickets WHERE uid LIKE %q GROUP BY uid'
local QLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal FROM tickets WHERE uid LIKE %q'

local DIRTY	 = {clave=true, tbname=true, fruit=true}
local TOLL	 = {costo=true, impuesto=true, descuento=true, rebaja=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true}
local PRCS	 = {prc1=true, prc2=true, prc3=true}

local INU	 = 'INSERT INTO updates (clave, campo, valor) VALUES (%s, %q, %s)'
local UPQ	 = 'UPDATE %q SET %s %s'
local COSTOL 	 = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

-- COSTOL = PRINTF("%d", costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)+0.5)
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

-- XXX should use fd.slice instead of fd.reduce XXX
local function addTicket(conn, conn2, msg)
    local tag	    = msg:match'%a+'
    local data, uid = msg:match'&([^!]+)&uid=([^!]+)$'
    if countN(data, 'query=') > 6 then
	fd.slice(5, fd.wrap(data:gmatch'query=([^&]+)'), fd.map(process(uid, tag, conn2)), into'tickets', conn)
    else
	fd.reduce(fd.wrap(data:gmatch'query=([^&]+)'), fd.map(process(uid, tag, conn2)), into'tickets', conn)
    end
    return uid
end

local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat(v, k)
    local vv = smart(v, k)
    return format('%s = %s', k, vv)
end

local function reformat2(clave)
    clave = tointeger(clave) or format('%q', clave) -- "'%s'"
    return function(v, k)
	local vv = smart(v, k)
	return format(INU, clave, k, vv)
    end
end

local function found(a, b) return fd.first(fd.keys(a), function(_,k) return b[k] end) end

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function up_faltantes()
--    Otra BASE de DATOS XXX
--    w.faltantes = 0
--    qry = format('UPDATE faltantes SET faltante = 0 %s', clause)
--    assert(conn.exec( qry ), qry)
end

local function up_costos(w, a) -- conn
    for k in pairs(TOLL) do w[k] = nil end
    fd.reduce(fd.keys(a), fd.filter(function(_,k) return k:match'^precio' or k:match'^costo' end), fd.merge, w)
    return w
end

local function up_precios(conn, w, clause)
    local qry = format('SELECT * FROM precios %s LIMIT 1', clause)
    local a = fd.first(conn.query(qry), function(x) return x end)

    fd.reduce(fd.keys(w), fd.filter(function(_,k) return k:match'prc' end), fd.map(function(_,k) return k:gsub('prc', 'precio') end), fd.rejig(function(k) return a[k], k end), fd.merge, w)

    for k in pairs(PRCS) do w[k] = nil end

    return a, w
end

local function addUpdate(msg, conn, conn2) -- conn, conn2
    local w = {}
    for k,v in msg:gmatch'([%a%d]+)=([^&]+)' do w[k] = asnum(v) end

    local clave  = w.clave
    local tbname = w.tbname
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(w, TOLL)

    if w.fecha then w.fecha = HOY end -- only fecha updates!!!XXX
    if toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map( reformat ), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format(UPQ, 'datos', concat(u, ', '), clause)

---[[
--    print( qry )
    pcall(conn.exec( qry ))
    if toll then
	qry = format(UPQ, 'datos', COSTOL, clause)
	pcall(conn.exec( qry ))
    end

    if found(w, PRCS) or toll then
	local a = up_precios(conn, w, clause)
	if toll then up_costos(w, a) end
    end

    u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat2(clave)), fd.into, {})
--    print( concat(u,'\n') )
    for _,q in ipairs(u) do assert(conn2.exec( q )) end

    return true
--]]
end

local function addName(o)
    local pid = asnum(o.uid:match'P([%d%a]+)')
    o.nombre = pid and PEOPLE[pid] or 'NaP';
    return o
end

local function jsonName(o) return asJSON(addName(o)) end

local function toCents(w)
    if w.total then w.total = format('%.2f', w.total) end
    return w
end

local function dumpFEED(conn, path, qry, clause) -- XXX correct FIN json
    if clause and conn.count( 'tickets', clause ) == 0 then return false end
    dump(path, asJSON(fd.reduce(conn.query(qry), fd.map(toCents), fd.map(addName), fd.into, {})))
    return true
end

local function fields(a, t) return fd.reduce(a, fd.map(function(k) return t[k] end), fd.into, {}) end

local function bixolon(uid, conn)
    local HEAD = {'tag', 'uid', 'total', 'nombre'}
    local DATOS = {'clave', 'desc', 'qty', 'rea', 'unitario', 'subTotal'}

    local head = addName(fd.first(conn.query(format(QHEAD, uid)), function(x) return x end))

    local data = ticket(head, fd.reduce(conn.query(format(QLPR, uid)), fd.into, {}))

    local skt = stdout -- popen(PRINTER, 'w')
    if #data > 8 then
	data = fd.slice(4, data, fd.into, {})
	fd.reduce(data, function(v) skt:write(concat(v,'\n'), '\n') end)
    else
	skt:write( concat(data,'\n') )
    end
    skt:close()

    return true
end

--[[
local function facturar(uid, conn)
    local HEAD = {'tag', 'uid', 'total', 'nombre'}
    local DATOS = {'clave', 'desc', 'qty', 'rea', 'unitario', 'subTotal'}

    local head = addName(fd.first(conn.query(format(QHEAD, uid)), function(x) return x end))

    local data = fd.reduce(conn.query(format(QLPR, uid)), fd.into, {})

    local skt = popen(PRINTER, 'w')
	if #data > 8 then
	    fd.slice(4, function end)
	else
	    skt:write( concat(ticket(head, data), '\n') )
	end
    skt:close()

    return true
end
--]]

--[[
local function escape(a) return fd.reduce(a, fd.map(function(x) return format('%q',x) end), fd.into, {}) end

local function getHeader(conn)
    local ret = escape(conn.header'datos')
    remove(ret) -- uidSAT
    insert(ret, 6, remove(ret)) -- rebaja
    remove(ret) -- costol
    ret = concat(ret, ', ')
    return format('%s [%s]', 'header', ret)
end
--]]

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
do
    local people = assert( dbconn'personas' )
    fd.reduce(people.query'SELECT * FROM empleados', fd.rejig(function(o) return o.nombre, asnum(o.id) end), fd.merge, PEOPLE)
end
--
-- -- -- -- -- --
--
-- Run loop
--

local function which(week) return TODAY==week and WEEK or assert(dbconn( week )) end

local function feedPath(fruit) return format('%s/caja/json/%s-feed.json', HOME, fruit) end

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
	local msg = jsonName(fd.first(WEEK.query(qry), function(x) return x end))
	queues:send_msgs{'WEEK', format('feed %s', msg)}
	bixolon(uid, WEEK)
	print(msg, '\n')

    elseif cmd == 'feed' then
	local fruit = msg:match'%s(%a+)' -- secs = %s(%d+)$
	local t = date('%FT%T', now()):sub(1, 10)
	local qry = format(QUID, '>', t)
	local cls = format(CLAUSE, '>', t)
	if dumpFEED(WEEK, feedPath(fruit), qry, cls) then
	    print'Updates stored and dumped\n'
	    queues:send_msgs{'WEEK', format('%s feed %s-feed.json', fruit, fruit)}
	end

    elseif cmd == 'ledger' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local week  = msg:match'week=([^!&]+)'
	local qry   = format(QUID, 'LIKE', uid..'%')
	local cls   = format(CLAUSE, 'LIKE', uid..'%')
	if dumpFEED(which(week), feedPath(fruit), qry, cls) then
	    print'Historic data stored and dumped\n'
	    queues:send_msgs{'WEEK', format('%s ledger %s-feed.json', fruit, fruit)}
	end

    elseif cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local week  = msg:match'week=([^!&]+)'
	local qry   = format(QTKT, uid)
	dumpFEED(which(week), feedPath(fruit), qry, false)
	print'Data for UID stored and dumped\n'
	queues:send_msgs{'WEEK', format('%s uid %s-feed.json', fruit, fruit)}

    elseif cmd == 'bixolon' then
	local uid, week = msg:match'%s([^!]+)%s([^!]+)'
	bixolon(uid, which(week))
	print('Printing data ...\n')

    elseif cmd == 'factura' then
	local uid, week = msg:match'%s([^!]+)%s([^!]+)'
	facturar(uid, which(week))
	queues:send_msgs{'WEEK', format('factura %s', uid)}

    elseif cmd == 'update' then
	local fruit = msg:match'fruit=(%a+)'
	addUpdate(msg, PRECIOS, WEEK)
	queues:send_msgs{'ADMIN', format('%s update %s', fruit, date('%FT%T', now()):sub(1, 10))}
	print('Data updated correctly\n')
    end

end

--[[
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'DB' then
	    queues:send_msgs{id, 'Bye DB'}
	    break
	end
    end

    elseif cmd == 'query' then
	local fruit = msg:match'fruit=(%a+)'
print(msg, '\n')
	print('Querying database ...\n')
	local f = popen(format('%s/dump-query.lua %s', APP, msg))
	local v = f:read'l' -- :gsub('%s+%d$', '')
	f:close()
print(v,'\n')
	queues:send_msgs{'WEEK', format('%s query %s', fruit, v)}
--]]

