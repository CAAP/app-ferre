#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'
local split	  = require'carlos.string'.split
local connect	  = require'carlos.sqlite'.connect
local newTable    = require'carlos.sqlite'.newTable
local into	  = require'carlos.sqlite'.into
local asnum	  = require'carlos.ferre'.asnum
local asweek	  = require'carlos.ferre'.asweek
local aspath	  = require'carlos.ferre'.aspath
local dbconn	  = require'carlos.ferre'.dbconn
local now	  = require'carlos.ferre'.now

local rconnect	  = require'redis'.connect
local asJSON	  = require'json'.encode
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local posix	  = require'posix.signal'

local unpack	  = table.unpack
local tointeger	  = math.tointeger
local format	  = string.format
local env	  = os.getenv
local exit	  = os.exit
local print	  = print
local assert	  = assert

local HOY	  = os.date('%d-%b-%y', now())

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	  = env'STREAM_IPC'

local QRY	  = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUP	  = 'UPDATE %q SET %s %s'
local QUID	  = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QLPR	  = 'SELECT * FROM lpr WHERE uid LIKE %q'
local QTKT	  = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local COSTOL 	  = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

local client	  = assert( rconnect('127.0.0.1', '6379') )

local IDS	  = 'app:uuids:'
local QIDS	  = 'queue:uuids:'
local UVS	  = 'app:updates:version'

local FERRE, WEEK, INDEX

local NOMBRES	  = { A = 'caja' }
local WKDB 	  = asweek(now())

local TOLL	  = assert( client:smembers'const:toll' )
local PRCS	  = assert( client:smembers'const:precios' )
local DIRTY	  = assert( client:smembers'const:dirty' )
local ISSTR	  = fd.reduce(client:smembers'const:isstr', fd.rejig(function(k) return true, k end), fd.merge, {})

--------------------------------
-- Local function definitions --
--------------------------------
--
local function header(uid) return fd.first(WEEK.query(format(QUID, uid)), function(x) return x end) end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function oneItem(o)
    for k,v in o.data:gmatch'([%a%d]+)|([^|]+)' do o[k] = asnum(v) end
    local lbl = 'u' .. o.precio:match'%d$'
    local rea = (100-o.rea)/100.0
    o.data = nil

    local b = fd.first(FERRE.query(format(QRY, o.clave)), function(x) return x end)
    fd.reduce(fd.keys(o), fd.merge, b)
    b.precio = b[o.precio]; b.unidad = b[lbl];
    b.prc = o.precio; b.unitario = b.rea > 1 and round(b.precio*rea, 2) or b.precio

    return b
end

local function addTicket(uuid)
    local ID = IDS..uuid
    if client:exists(ID) then
	local uid, tag, pid = client:hget(ID, 'uid'), client:hget(ID, 'cmd'), tointeger(client:hget(ID, 'pid'))
	local nombre = NOMBRES[pid] or 'NaP'
	local data = split(client:hget(ID, 'data'):sub(7), '&query=')
	if #data > 6 then
	    fd.slice(5, data, fd.map(function(s) return {data=s, uid=uid, tag=tag, nombre=nombre} end), fd.map(oneItem), fd.map(indexar), into'tickets', WEEK)
	else
	    fd.reduce(data, fd.map(function(s) return {data=s, uid=uid, tag=tag, nombre=nombre} end), fd.map(oneItem), fd.map(indexar), into'tickets', WEEK)
	end
	return uid
    end
end

local function lpr(uid, hdr)
    local qry = format(QLPR, uid)
    local data = fd.reduce(WEEK.query(qry), fd.into, {})
    local k = QIDS..uid
    client:rpush(k, unpack(ticket(hdr, data)))
    return client:expire(k, 120)
end

--
-- -- -- -- -- --
--

local function found(ks, b) return fd.first(ks, function(k) return b[k] end) end
local function sanitize(ks)
    local kk = fd.reduce(ks, fd.rejig(function(k) return true, k end), fd.merge, {})
    return function(_,k) return not(kk[k]) end
end
local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat(v, k)
    local vv = smart(v, k)
    return format('%s = %s', k, vv)
end

local function updateOne(w)
    local clave = tointeger(w.clave) or format('%q', w.clave)
--    local tbname = w.tbname
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(TOLL, w)

    if w.fecha or toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format(QUP, 'datos', concat(u, ', '), clause)

    pcall(FERRE.exec( qry ))
    if toll then
	qry = format(QUP, 'datos', COSTOL, clause)
	pcall(FERRE.exec( qry ))
    end

    local a = fd.reduce(fd.keys(w), fd.filter(sanitize(TOLL)), fd.filter(sanitize(PRCS)), fd.merge, {})
    local UP = fd.first(FERRE.query(QRY:format(clave)), function(x) return x end) -- new/update as PRECIO

    if toll then -- ALL prices & costol has changed
	fd.reduce(fd.keys(UP), fd.filter(function(_,k) return k:match'^precio' or k:match'^costo' end), fd.merge, a)
    elseif found(PRCS, w) then -- only a few prices have changed
	fd.reduce(PRCS, fd.filter(function(k) return a[k] end), fd.map(function(k) return k:gsub('prc', 'precio') end), fd.rejig(function(k) return UP[k], k end), fd.merge, a)
    end

    -- ### -- ### -- ### -- ### -- ### --

    u = (fd.first(WEEK.query'SELECT MAX(vers) vers FROM updates', function(x) return x end).vers or 0) + 1
    a.store = 'PRICE'
    local msg = asJSON{a, {vers=u, week=TODAY, store='VERS'}}
    qry = format("INSERT INTO updates VALUES (%d, %s, '%s')", u, clave, msg)
    assert( WEEK.exec( qry ) )

    local v = asJSON{vers=u, week=WKDB}
    client:set(UVS, v)
    print( '\nversion:', v, '\n' )

    -- notify cloud service XXX

    return format('version', v)
end

local function setBlank(clave)
    local w = fd.first(FERRE.query(QRY:format(clave):gsub('precios', 'datos')), function(x) return x end)
    for k in pairs(w) do w[k] = ISSTR[k] and '' or 0 end
    w.clave = clave
    w.desc = 'VVVVV'
    return w
end

---------------------------------
-- Program execution statement --
---------------------------------
--
--
local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
-- Database connection(s)
--
do
    local WSQL	  = 'sql:week'
    local TABS	  = { tickets  = client:hget(WSQL, 'tickets'),
		      updates  = client:hget(WSQL, 'updates'),
	    	      facturas = client:hget(WSQL, 'facturas') }
    INDEX = fd.reduce(split(TABS.tickets, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})
-- -- -- -- -- --
    WEEK = assert( dbconn( WKDB, true ) )
    fd.reduce(fd.keys(TABS), function(schema, tbname) WEEK.exec(format(newTable, tbname, schema)) end)
    WEEK.exec( client:hget(WSQL, 'uids') ) -- temp views
    WEEK.exec( client:hget(WSQL, 'sales') ) -- temp views
    WEEK.exec( client:hget(WSQL, 'lpr') ) -- temp views
    print(WKDB, "DB was successfully open\n")
-- -- -- -- -- --
    FERRE = assert( dbconn'ferre' )
    print("ferre DB was successfully open\n")
    print("items in precios:", FERRE.count'precios', "\n")
-- -- -- -- -- --
    FERRE.exec(format('ATTACH DATABASE %q AS people', aspath'personas'))
    fd.reduce(FERRE.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, NOMBRES)
    FERRE.exec'DETACH DATABASE people'
    print("personas DB was successfully read\n")
end
-- -- -- -- -- --
--

-- -- -- -- -- --
--

--
--
-- Initilize server(s)

local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:linger(0) )

assert( tasks:set_id'DB' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--[[
-- -- -- -- -- --
--
local printer = assert(CTX:socket'PUSH')

assert( printer:immediate( true ) )

assert( printer:connect( BIXOLON ) )

print('\nSuccessfully connected to:', BIXOLON)
--
-- -- -- -- -- --
--]]

-- -- -- -- -- --
--

while true do

    print'+\n'

    pollin{tasks}

    if tasks:events() == 'POLLIN' then

	local msg, more = tasks:recv_msgs()
	local cmd = msg[1]:match'%a+'

	if cmd == 'ticket' or cmd == 'presupuesto' or cmd == 'pagado' then
	    local uid = addTicket(msg[2])
	    if uid then
		local hdr = header(uid)
	        tasks:send_msgs('SSE', 'feed', asJSON(hdr))
		lpr( uid, hdr )
--		printer:send_msg( uid ) XXX
		print('\nUID:', uid, '\n')		
	    end

	elseif cmd == 'update' then
	    msg = msg[2]
	    local w = {}
	    for k,v in urldecode(msg):gmatch'([%a%d]+)=([^&]+)' do w[k] = asnum(v) end
	    for k,v in urldecode(msg):gmatch'([%a%d]+)=&' do w[k] = '' end
	    local vers = updateOne( w )
	    tasks:send_msgs('SSE', 'version', vers)
	    print('\nversion:', vers, '\n')

	elseif cmd == 'eliminar' then
	    local clave = msg[2]:match'clave=([%a%d]+)'
	    local vers = updateOne( setBlank(clave) )
	    tasks:send_msgs('SSE', 'version', vers)
	    print('\nversion:', vers, '\n')



	elseif cmd == 'bixolon' then
	    local uid = msg[2]:match'uid=([^!]+)'
	    local hdr = header(uid)
	    lpr( uid, hdr )
--	    printer:send_msg( uid ) XXX

	elseif cmd == 'uid' then
	    local fruit = msg[2]:match'fruit=(%a+)'
	    local uid   = msg[2]:match'uid=([^!&]+)'
	    local qry = format(QTKT, uid)
	return fruit, conn, qry

	elseif cmd == 'feed' then

	end


    end

end
