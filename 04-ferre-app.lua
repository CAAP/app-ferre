#! /usr/bin/env lua53

-- Import Section
--

local fd	  = require'carlos.fold'

local context	  = require'lzmq'.context
--local proxy	  = require'lzmq'.proxy
local pollin	  = require'lzmq'.pollin
local asJSON	  = require'json'.encode

local receive	  = require'carlos.ferre'.receive
local send	  = require'carlos.ferre'.send
local aspath	  = require'carlos.ferre'.aspath
local now	  = require'carlos.ferre'.now
local asnum	  = require'carlos.ferre'.asnum
local newUID	  = require'carlos.ferre'.newUID
local urldecode	  = require'carlos.ferre'.urldecode
local response	  = require'carlos.html'.response
local split	  = require'carlos.string'.split
local connect	  = require'carlos.sqlite'.connect

local assert	  = assert
local concat	  = table.concat
local remove	  = table.remove
local exec	  = os.execute
local format	  = string.format
local print	  = print
local tostring	  = tostring
local tonumber	  = tonumber
local tointeger   = math.tointeger
local pcall	  = pcall

local APP	  = require'carlos.ferre'.APP

local HOY	  = os.date('%d-%b-%y', now())

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = 'tcp://*:5040'
local UPSTREAM	 = 'ipc://upstream.ipc'
local STREAM 	 = 'ipc://stream.ipc'

local OK	 = response{status='ok'}

local PRECIOS	 = connect':inmemory:'

local PID	 = { A = 'caja' }

local ISTKT 	  = {ticket=true, presupuesto=true}
local TOLL	  = {costo=true, impuesto=true, descuento=true, rebaja=true}
local DIRTY	  = {clave=true, tbname=true, fruit=true}
local ISSTR	  = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local QRY	  = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local UPQ	  = 'UPDATE %q SET %s %s'
local COSTOL 	  = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

local QDESC	 = 'SELECT clave FROM datos WHERE desc LIKE %q ORDER BY desc LIMIT 1'

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

local function byDesc(conn, s)
    local qry = format(QDESC, s:gsub('*', '%%')..'%')
    local o = fd.first(conn.query(qry), function(x) return x end)
    return (o and o.clave or '')
end

local function byClave(conn, s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    local o = fd.first(conn.query(qry), function(x) return x end)
    return o and asJSON( o ) or ''
end

local function queryDB(msg)
    if msg:match'desc' then
	local ret = msg:match'desc=([^!&]+)'
	if ret:match'VV' then
	    return byClave(PRECIOS, byDesc(PRECIOS, ret))
	else
	    return byDesc(PRECIOS, ret)
	end

    elseif msg:match'clave' then
	local ret = msg:match'clave=([%a%d]+)'
	return byClave(PRECIOS, ret)

    end
end

local function updateOne(conn, msg)
    local w = {}
    for k,v in msg:gmatch'([%a%d]+)=([^&]+)' do w[k] = asnum(v) end

    local clave  = w.clave
    local tbname = w.tbname
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(w, TOLL)

    if w.fecha or toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format(UPQ, 'datos', concat(u, ', '), clause)

    pcall(conn.exec( qry ))
    if toll then
	qry = format(UPQ, 'datos', COSTOL, clause)
	pcall(conn.exec( qry ))
    end

    return asJSON(w)
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

local function asTicket(cmd, uid, persona, msg)
    remove(msg, 1)
    return fd.reduce(msg, fd.map(urldecode), fd.map(process(uid, persona, cmd)), fd.into, {cmd})
end


local function distill(a)
    local data = concat(a)
    if data:match'GET' then
	return format('%s %s', data:match'GET /(%a+)%?([^%?]+) HTTP')
    elseif data:match'POST' then
	return format('%s %s', data:match'POST /(%a+)', data:match'pid=[^%s]+')
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
--

do
    local path = aspath'ferre'
    assert( PRECIOS.exec(format('ATTACH DATABASE %q AS ferre', path)) )
    assert( PRECIOS.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
    assert( PRECIOS.exec'DETACH DATABASE ferre' )

    path = aspath'personas'
    PRECIOS.exec(format('ATTACH DATABASE %q AS people', path))
    fd.reduce(PRECIOS.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, PID)
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

--
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'STREAM')

assert( server:notify(false) )

assert(server:bind( ENDPOINT ))

print('Successfully bound to:', ENDPOINT, '\n')

-- -- -- -- -- --
--

local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')

-- -- -- -- -- --
--

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'app' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

-- -- -- -- -- --
--

tasks:send_msg'OK'

while true do
print'+\n'

    pollin{server}

    local id, msg = receive(server)
    msg = distill(msg)
    local cmd = msg:match'%a+'

    if msg then
	-- send OK
	send(server, id, OK)
	----------------------
	print(msg, '\n')
	----------------------
	-- reply queries
	if cmd == 'query' then
	    local fruit = msg:match'fruit=(%a+)'
	    msgr:send_msg( format('%s query %s', fruit, queryDB(msg)) )

	else
	    ----------------------
	    -- pre-process & store updates
	    if cmd == 'update' then
		msg = format('update %s', updateOne(PRECIOS, msg))
	    end
	    ----------------------
	    -- convert into MULTI-part msgs
	    if msg:match'query=' then
		local ret = split(msg, '&query=')
		if ISTKT[cmd] then
		    local pid = asnum( msg:match'pid=([%d%a]+)' )
	 	    local uid = newUID()..pid
		    ret = asTicket(cmd, uid, PID[pid] or 'NaP', ret)
		end
		tasks:send_msgs( ret )
	    else tasks:send_msg( msg ) end
	end

    else
	print'Received empty message ;-(\n'

    end

    send(server, id, '') -- close socket

end

