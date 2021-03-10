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
local newuid	  = require'carlos.ferre'.newUID
local catchall	  = require'carlos.ferre'.catchall
local digest	  = require'carlos.ferre'.digest
local socket	  = require'lzmq'.socket
local pollin	  = require'lzmq'.pollin

local rconnect	  = require'redis'.connect
local asJSON	  = require'json'.encode
local deserialize = require'carlos.ferre'.deserialize
local serialize   = require'carlos.ferre'.serialize
local posix	  = require'posix.signal'

local concat	  = table.concat
local tointeger	  = math.tointeger
local floor	  = math.floor
local format	  = string.format
local env	  = os.getenv
local exit	  = os.exit
local pairs	  = pairs
local tonumber    = tonumber
local tostring	  = tostring
local print	  = print
local assert	  = assert
local type	  = type
local pcall	  = pcall

local HOY	  = os.date('%d-%b-%y', now())

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	  = env'STREAM_IPC'
local TIENDA	  = env'TIENDA'

local QRY	  = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUP	  = 'UPDATE %q SET %s %s'
local QQRY	  = "INSERT INTO queries VALUES (%q, %s, %q)"

local COSTOL 	  = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

local client	  = assert( rconnect('127.0.0.1', '6379') )

local IDS	  = 'app:uuids'
local QTKT	  = 'queue:tickets'
local QUPS	  = 'queue:ups:'
local UVER	  = 'app:updates:version'
local TTKT 	  = 'app:tickets:FA-BJ-'

local FERRE, WEEK, INDEX

local NOMBRES	  = { A = 'caja' }
local EMPLEADOS	  = {}
local WKDB 	  = asweek(now())

local TOLL	  = assert( client:smembers'const:toll' )
local PRCS	  = assert( client:smembers'const:precios' )
local DIRTY	  = assert( client:smembers'const:dirty' )
local ISSTR	  = fd.reduce(client:smembers'const:isstr', fd.rejig(function(k) return true, k end), fd.merge, {})

--------------------------------
-- Local function definitions --
--------------------------------
--

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function round(n, d) return floor(n*10^d+0.5)/10^d end

local function oneItem(o)
    local lbl = 'u' .. o.precio:match'%d$'
    local rea = (100-o.rea)/100.0
    o.nombre = NOMBRES[tointeger(o.pid)] or 'NaP'
    o.tag = o.cmd

    local b = fd.first(FERRE.query(format(QRY, o.clave)), function(x) return x end)
    fd.reduce(fd.keys(o), fd.merge, b)
    b.precio = b[o.precio]; b.unidad = b[lbl];
    b.prc = o.precio; b.unitario = b.rea > 1 and round(b.precio*rea, 2) or b.precio

    return b
end

local function addTicket(uuid)
    if client:hexists(IDS, uuid) then
	local data = deserialize(client:hget(IDS, uuid)) -- serialized table of objects
	client:hdel(IDS, uuid)

	data = fd.reduce(data, fd.map(oneItem), fd.map(indexar), fd.into, {})

	client:hset(QTKT, uuid, serialize(data))

	if #data > 6 then
	    fd.slice(5, data, into'tickets', WEEK)
	else
	    fd.reduce(data, into'tickets', WEEK)
	end
	return uuid
    end
end

--[[
local function addTicketx( uid )
    local k = 'queue:tickets:'..uid
    local data = client:lrange(k, 0, -1)
    if #data > 6 then
	fd.slice(5, data, fd.map(deserialize), into'tickets', WEEK)
    else
	fd.reduce(data, fd.map(deserialize), into'tickets', WEEK)
    end
    local k = TTKT..uid:match':(%d+)$'
    client:set(k, uid)
    return uid
end
--]]

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

local function execUP( f )
    local e,s = pcall(f)
    return (not(e) and s or '')
end

local function qryExec(q)
    local s
    if q:match'datos' then
	s = execUP(function() return FERRE.exec(q) end)
    else
	s = execUP(function() return WEEK.exec(q) end)
    end
    print(q, s, '\n')
end

local function updateOne(w)
    local clave = w.clave
    local k = QUPS..clave
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(TOLL, w)

    if w.fecha or toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format('UPDATE datos SET %s %s', concat(u, ', '), clause)
    qryExec(qry)
    client:rpush(k, qry)


    if toll then
	qry = format('UPDATE datos SET %s %s', COSTOL, clause)
	qryExec(qry)
	client:rpush(k, qry)
    end

    -- ### -- ### -- ### -- ### -- ### --

    local a = {clave=clave, desc=w.desc}
    if w.desc and w.desc:match'VVV' then goto FEED end

    a = fd.reduce(fd.keys(w), fd.filter(sanitize(TOLL)), fd.filter(sanitize(PRCS)), fd.merge, {}) -- CLONE

    do
	local UP = fd.first(FERRE.query(QRY:format(clave)), function(x) return x end) -- new/update as PRECIO
	if toll then -- ALL prices & costol has changed
	    fd.reduce(fd.keys(UP), fd.filter(function(_,k) return k:match'^precio' or k:match'^costo' end), fd.merge, a)
	elseif found(PRCS, w) then -- only a few prices have changed
	    fd.reduce(PRCS, fd.filter(function(k) return a[k] end), fd.map(function(k) return k:gsub('prc', 'precio') end), fd.rejig(function(k) return UP[k], k end), fd.merge, a)
	end
    end

    -- ### -- ### -- ### -- ### -- ### --
::FEED::
    clave = tointeger(clave) or format('%q', clave)
    u = newuid():sub(1,-2) -- remove last 'P' character
    a.store = 'PRICE'
    local msg = asJSON{a, {version=u, store='VERS'}}
    qry = format("INSERT INTO updates VALUES ('%s', %s, '%s')", u, clave, msg)
    qryExec(qry)
    client:rpush(k, qry)

    local dgst = digest(client:get(UVER), u)
    qry = format(QQRY, u, dgst, '$QUERY') -- md5 digest

    client:rpush(k, qry)
    -- QUERY --
    qry = qry:gsub('$QUERY', serialize(client:lrange(k, 0, -1)))
    qryExec(qry)

    client:expire(k, 120)

    return u, dgst
end

local function setBlank(o)
    local clave = o.clave
    local w = fd.first(FERRE.query(QRY:format(clave):gsub('precios', 'datos')), function(x) return x end)
    for k in pairs(w) do o[k] = ISSTR[k] and '' or 0 end
    o.clave = clave
    o.desc = 'VVVVV'
    return o
end

------------------------------------------------------------

local function storetkt(skt, msg)
    local s = msg[2] -- serialized object {uuid, uid, pid}
--    if not s then print'*****ERROR*****'; return false end XXX
    local w = deserialize(s)
    local uuid = addTicket(w.uuid)
    if uuid then
	skt:send_msgs{'reroute', 'inmem', 'ticket', s}
	print('\nUID:', w.uid, '\n')		
	-- save uid per person into msgs
	w.cmd = 'msgs'
	skt:send_msgs{'msgs', serialize(w)}
	-- notify cloud service | external peer
--	w.cmd = 'ticketx'
--	skt:send_msg( s )
    end
end

------------------------------------------------------------

local function notify(skt, o)
    client:set(UVER, o.version)
    skt:send_msgs{'reroute', 'inmem', 'update', serialize(o)}
    o.cmd = 'version'
--    o.week = WKDB
    skt:send_msgs{'reroute', 'SSE', serialize(o)}
    -- notify external peer --
    o.cmd = 'updatex'
    skt:send_msgs{'reroute', 'SSE', serialize(o)}
end

------------------------------------------------------------

local function updateitem(skt, msg)
    local cmd, s = msg[1], msg[2]
    local w = deserialize(s)

    if cmd == 'eliminar' then setBlank(w) end

    local v, dgst = updateOne(w)
    notify(skt, {version=v, clave=w.clave, digest=dgst})
    print('\nversion:', v, '\n')
end

------------------------------------------------------------

local function employees(skt, msg)
    local cmd, s = msg[1], msg[2]
    local w = deserialize(s)
    w.data = EMPLEADOS
    skt:send_msgs{'reroute', 'SSE', serialize(w)}
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
		      queries  = client:hget(WSQL, 'queries'),
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
    fd.reduce(FERRE.query'SELECT * FROM empleados', fd.into, EMPLEADOS)
    fd.reduce(EMPLEADOS, fd.map(function(p) return p.nombre end), fd.into, NOMBRES)
--    fd.reduce(FERRE.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, NOMBRES)
    FERRE.exec'DETACH DATABASE people'
    print("personas DB was successfully read\n")
end

--
--
-- Initilize server(s)

local tasks = assert(socket'DEALER')

assert( tasks:opt('immediate', true) )

assert( tasks:opt('linger', 0) )

assert( tasks:opt('id', 'DB') )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--
-- -- -- -- -- --
--

local router = { ticket=storetkt,   presupuesto=storetkt, facturar=storetkt,
		 update=updateitem, eliminar=updateitem,  people=employees }

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{tasks}

    local events = tasks:opt'events'

    if events.pollin then

	-- two messages received: cmd & [binser] Lua Object --
	local msg = tasks:recv_msgs()
	local cmd = msg[1]

	print(concat(msg, ' '), '\n')

	if cmd == 'OK' then
	else catchall(router, tasks, cmd, msg, {'reroute', 'SSE', ''}) end -- router[cmd](tasks, msg)

    end

end

--[[
	if cmd == 'updatex' then -- cmd, clave, vers
	    local clave = msg[2]
	    local vers = msg[3]
	    local k = QIDS..clave
	    local qs = client:lrange(k, 0, -1)
	    -- QUERY --
	    qs[#qs] = qs[#qs]:gsub('$QUERY', b64(serialize(qs)))
	    --
	    fd.reduce(qs, qryExec)
	    notify(clave, vers)
	    print('\nversion:', vers, '\n')
	    -- DO NOT notify cloud service | external peer

	elseif cmd == 'ticketx' then
	    local uid = addTicketx(msg[2])
	    tasks:send_msgs{'inmem', 'ticket', uid}
	    print('\nUID:', uid, '\n')		
	    -- DO NOT notify cloud service | external peer

	end
--]]
