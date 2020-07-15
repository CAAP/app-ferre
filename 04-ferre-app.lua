#! /usr/bin/env lua53

-- Import Section
--

local fd	  = require'carlos.fold'

local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local asJSON	  = require'json'.encode
local fromJSON    = require'json'.decode
local posix	  = require'posix.signal'

local aspath	  = require'carlos.ferre'.aspath
local now	  = require'carlos.ferre'.now
local asnum	  = require'carlos.ferre'.asnum
local newUID	  = require'carlos.ferre'.newUID
local urldecode	  = require'carlos.ferre'.urldecode
local split	  = require'carlos.string'.split
local connect	  = require'carlos.sqlite'.connect

local assert	  = assert
local ipairs	  = ipairs
local pairs	  = pairs
local concat	  = table.concat
local remove	  = table.remove
local exec	  = os.execute
local format	  = string.format
local print	  = print
local tostring	  = tostring
local tonumber	  = tonumber
local tointeger   = math.tointeger
local floor	  = math.floor
local pcall	  = pcall
local exit	  = os.exit

local APP	  = require'carlos.ferre'.APP

local HOY	  = os.date('%d-%b-%y', now())

local STREAM	  = os.getenv'STREAM_IPC'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local PRECIOS	 = assert( connect':inmemory:' )

local PID	 = { A = 'caja' }

local ISTKT 	 = {ticket=true, presupuesto=true}
local TOLL	 = {costo=true, impuesto=true, descuento=true, rebaja=true}
local DIRTY	 = {clave=true, tbname=true, fruit=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local QRY	 = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local UPQ	 = 'UPDATE %q SET %s %s'
local COSTOL 	 = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

local QDESC	 = 'SELECT clave FROM datos WHERE desc LIKE %q ORDER BY desc LIMIT 1'

local UUID	 = {}
local CACHE	 = {}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function round(n, d) return floor(n*10^d+0.5)/10^d end

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function found(a, b) return fd.first(fd.keys(a), function(_,k) return b[k] end) end

local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat(v, k)
    local vv = smart(v, k)
    return format('%s = %s', k, vv)
end

local function byDesc(s)
    local qry = format(QDESC, s:gsub('*', '%%')..'%')
    local o = fd.first(PRECIOS.query(qry), function(x) return x end)
    return (o and o.clave or '')
end

local function byClave(s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    local o = fd.first(PRECIOS.query(qry), function(x) return x end)
    return o and asJSON( o ) or ''
end

local function queryDB(msg)
    if msg:match'desc' then
	local ret = msg:match'desc=([^!&]+)'
	if ret:match'VV' then
	    return byClave(byDesc(ret))
	else
	    return byDesc(ret)
	end

    elseif msg:match'clave' then
	local ret = msg:match'clave=([%a%d]+)'
	return byClave(ret)

    end
end

local function queryRFC(rfc)
    local QRY = format('SELECT * FROM clientes WHERE rfc LIKE "%s%%" LIMIT 4', rfc)
    local ans = fd.reduce(PRECIOS.query(QRY), fd.into, {})
    return #ans > 0 and asJSON(ans) or '[]'
end

local function updateOne(w)
    local clave  = w.clave
--    local tbname = w.tbname
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(w, TOLL)

    if w.fecha or toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format(UPQ, 'datos', concat(u, ', '), clause)

    pcall(PRECIOS.exec( qry ))
    if toll then
	qry = format(UPQ, 'datos', COSTOL, clause)
	pcall(PRECIOS.exec( qry ))
    end

    return asJSON(w)
end

local function setBlank(clave)
    local w = fd.first(PRECIOS.query(QRY:format(clave):gsub('precios', 'datos')), function(x) return x end)
    for k in pairs(w) do w[k] = ISSTR[k] and '' or 0 end
    w.clave = clave
    w.desc = 'VVVVV'
    return w
end

local function process(uid, persona, tag)
    return function(q)
	local o = {uid=uid, tag=tag, nombre=persona}
	for k,v in q:gmatch'([%a%d]+)|([^|]+)' do o[k] = asnum(v) end
	local lbl = 'u' .. o.precio:match'%d$'
	local rea = (100-o.rea)/100.0

	local b = fd.first(PRECIOS.query(format(QRY, o.clave)), function(x) return x end)
	fd.reduce(fd.keys(o), fd.merge, b)
	b.precio = b[o.precio]; b.unidad = b[lbl];
	b.prc = o.precio; b.unitario = b.rea > 1 and round(b.precio*rea, 2) or b.precio

	return asJSON(b)
    end
end

local function asTicket(items, uid, persona, cmd, ret)
    remove(items, 1) -- pid
    return fd.reduce(items, fd.map(urldecode), fd.map(process(uid, persona, cmd)), fd.into, ret)
end

local function isuuid(its, cmd, pid, uuid, M)
    if uuid then
	if not(UUID[uuid]) then
	    UUID[uuid] = newUID()..pid
	    CACHE[uuid] = {cmd}
	end
	local w = asTicket(its, UUID[uuid], PID[pid] or 'NaP', cmd, CACHE[uuid])
	local N = #w
	if M == N then
	    UUID[uuid] = nil
	    CACHE[uuid] = nil
	    return w
	else return {'uuid', uuid, N, M} end
    else
	local uid = newUID()..pid
	return asTicket(its, uid, PID[pid] or 'NaP', cmd, {cmd})
    end
end

local function switch(msg, tasks)
    local cmd = msg[1]
    ----------------------
    -- pre-process & store updates
    if cmd == 'update' then
	msg = msg[2]
	local w = {}
	for k,v in urldecode(msg):gmatch'([%a%d]+)=([^&]+)' do w[k] = asnum(v) end
	for k,v in urldecode(msg):gmatch'([%a%d]+)=&' do w[k] = '' end
	msg = {'update', updateOne(w)} -- format('update %s', updateOne(w))
    end
    ----------------------
    -- delete entry aka set 'desc' to 'VVVV'
    if cmd == 'eliminar' then
	local clave = msg[2]:match'clave=([%a%d]+)'
	msg = {'update', updateOne(setBlank(clave))} -- format('update %s', updateOne(setBlank(clave)))
    end
    ----------------------
    -- convert into MULTI-part msgs
    if msg[2]:match'query=' then
	msg = msg[2]
	local ret = split(msg, '&query=')
	if ISTKT[cmd] and ret then -- ret is not nil
	    local pid = asnum(msg:match'pid=([%d%a]+)')
	    local uuid = msg:match'uuid=(%w+)'
	    local length = tointeger(msg:match'length=(%d+)')
	    ret = isuuid(ret, cmd, pid, uuid, length)
	end
	tasks:send_msgs( ret )
    else tasks:send_msgs( msg ) end
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

-- -- -- -- -- --
--

do
    local path = aspath'ferre'
    assert( PRECIOS.exec(format('ATTACH DATABASE %q AS ferre', path)) )
    assert( PRECIOS.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
    assert( PRECIOS.exec'DETACH DATABASE ferre' )

    path = aspath'personas'
    PRECIOS.exec(format('ATTACH DATABASE %q AS people', path))
    fd.reduce(PRECIOS.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, PID)
    PRECIOS.exec'CREATE TABLE clientes AS SELECT * FROM people.clientes'
    PRECIOS.exec'DETACH DATABASE people'

    PRECIOS.exec'CREATE VIEW precios AS SELECT clave, desc, fecha, u1, ROUND(prc1*costol/1e4,2) precio1, u2, ROUND(prc2*costol/1e4,2) precio2, u3, ROUND(prc3*costol/1e4,2) precio3, PRINTF("%d", costol) costol, uidSAT, proveedor, uidPROV FROM datos'

    print('items in datos:', PRECIOS.count'datos', '\n')
    print('items in precios:', PRECIOS.count'precios', '\n')
end

-- -- -- -- -- --
--

--
-- DUMP --
exec(format('%s/dump-people.lua', APP))

exec(format('%s/dump-header.lua', APP))

exec(format('%s/dump-units.lua', APP))

--
--
-- Initilize server(s)

local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:linger(0) )

assert( tasks:set_id'app' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

-- -- -- -- -- --
--

while true do

    print'+\n'

    pollin{tasks}

    if tasks:events() == 'POLLIN' then
	local msg = tasks:recv_msgs(true)
	local cmd = msg[1]

	print(concat(msg, '&'), '\n')

	if cmd == 'updatex' then
	    tasks:send_msgs{'update', updateOne( fromJSON(msg[2]) )}

	----------------------
	-- reply queries
	----------------------

	elseif cmd == 'query' then
	    local fruit = msg[2]:match'fruit=(%a+)'
	    tasks:send_msgs{'SSE', fruit, 'query', queryDB(msg)}

	elseif cmd == 'rfc' then
	    msg = msg[2]
	    local fruit = msg:match'fruit=(%a+)'
	    local rfc = msg:match'rfc=(%a+)'
	    tasks:send_msgs{'SSE', fruit, 'rfc', queryRFC(rfc)}

	else
	    ----------------------
	    -- pre-process & store updates
	    switch(msg, tasks)
	end

    end

end
