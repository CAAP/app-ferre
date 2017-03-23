#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local ex = require'ferre.extras'
local tkt = require'ferre.ticket'
local lpr = require'ferre.bixolon'
local precio = require'ferre.precio'

local ahora = ex.now()
local hoy = os.date('%d-%b-%y', ahora)
local today = os.date('%F', ahora)
local week = ex.week() -- os.date('Y%YW%U', mx())
local dbname = string.format('/db/%s.db', week)

local MM = {tickets={}, tabs={}, entradas={}, cambios={}, recording={}, streaming={}}

local servers = {}

local ups = {week=week, vers=0, store='VERS'}

local tags = {} -- Initialize later at init
local nombres = {} -- Initialize later at init

local function id2tag(id) return tags[id] or id end

local function pid2name(pid) return nombres[pid] or 'NaP' end

local function safe(f, msg)
    local ok,err = pcall(f)
    if not ok then print('Error: \n', msg or '',  err); return false end
end

local function asJSON(w) return string.format('data: %s', hd.asJSON(w)) end

local function sse( w )
    if not(w) then return ':empty' end
    local event = w.event
    w.event = nil
    local ret = w.ret or {}
    w.ret = nil
    local data = w.data or asJSON( w )
    ret[#ret+1] = 'event: ' .. event
    ret[#ret+1] = 'data: ['
    ret[#ret+1] = data
    ret[#ret+1] = 'data: ]'
    ret[#ret+1] = '\n'
    return table.concat( ret, '\n')
end

---
local function init( conn )
    print('Connected to DB', dbname, '\n')
    assert( conn.exec"ATTACH DATABASE '/db/ferre.db' AS FR" )
    assert( conn.exec"ATTACH DATABASE '/db/inventario.db' AS NV" )
    fd.reduce( conn.query'SELECT * FROM tags', function(a) tags[a.id] = a.nombre end )
    fd.reduce( conn.query'SELECT * FROM empleados', function(a) nombres[a.id] = a.nombre end )
    return conn
end

local function cambios( conn )
    local schema = 'vers INTEGER PRIMARY KEY, clave, campo, valor'

    assert( conn.exec( string.format(sql.newTable, 'updates', schema) ) )

    local costol = 'UPDATE datos SET costol = costo*(100+impuesto)*(100-descuento), fecha = %q %s'
    local isstr = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true}

    local function reformat(v, k)
	local vv = isstr[k] and string.format("'%s'", v) or (math.tointeger(v) or tonumber(v) or 0)
	return k .. ' = ' .. vv
    end

    local function up_costos(w, clause)
	w.costo = nil; w.impuesto = nil; w.descuento = nil; w.fecha = hoy;
	local qry = string.format(costol, w.fecha, clause)
	assert( conn.exec( qry ), 'Error executing: ' .. qry )
	w.faltante = 0
	qry = string.format('UPDATE faltantes SET faltante = 0 %s', clause)
	assert(conn.exec(qry), 'Error executing: ' .. qry)
-- VIEW precios is necessary to produce precio1, precio2, etc
	qry = string.format('SELECT * FROM precios %s', clause)
	ret = fd.first( conn.query( qry ), function(x) return x end )
	fd.reduce( fd.keys(ret), fd.filter(function(x,k) return k:match'^precio' end), fd.merge, w )
	    -- in order to update costo in admin.html
	w.costol = fd.first( conn.query(string.format('SELECT costol FROM datos %s', clause)), function(x) return x end ).costol
    end

    local function up_precios(w, clause)
	local ps = fd.reduce( fd.keys(w), fd.filter(function(_,k) return k:match'^prc' end), fd.map(function(_,k) return k end), fd.into, {} )
	for i=1,#ps do local k = ps[i]; w[k] = nil; ps[i] = k:gsub('prc','precio') end
	local ret = fd.first( conn.query(string.format('SELECT %s FROM precios %s', table.concat(ps, ', '), clause)), function(x) return x end )
	fd.reduce( fd.keys(ret), fd.merge, w )
    end

    function MM.cambios.add( w )
	local clave = w.clave
	local tbname = w.tbname
	local clause = string.format('WHERE clave LIKE %q', clave)

	w.id_tag = nil; w.args = nil; w.clave = nil; w.tbname = nil; -- SANITIZE

	if w.desc then w.desc = w.desc:upper() end

	local ret = fd.reduce( fd.keys(w), fd.map( reformat ), fd.into, {} )
	local qry = string.format('UPDATE %q SET %s %s', tbname, table.concat(ret, ', '), clause)
	assert( conn.exec( qry ), qry )

	if w.costo or w.impuesto or w.descuento then up_costos(w, clause) end

	if w.prc1 or w.prc2 or w.prc3 then up_precios(w, clause) end

	ret = {VERS=ups}
	ups.week = week
	ups.prev = ups.vers

	local function events(k, v)
	    local store = 'PRICE' -- stores[k] or 'PRICE'
	    if not ret[store] then ret[store] = {clave=clave, store=store} end
	    ret[store][k] = v
	end

	fd.reduce( fd.keys(w), fd.map(function(v,k) events(k, v); return {'', clave, k, v} end), sql.into'updates', conn )

	ups.vers = conn.count'updates'

	return {data=table.concat(fd.reduce(fd.keys(ret), fd.map( asJSON ), fd.into, {}), ',\n'), event='update'}
    end

-- XXX
    function MM.cambios.sse()
	return sse{data=asJSON(fd.reduce(fd.keys(ups), fd.merge, {prev=ups.vers})), event='update'}
    end

    return conn
end

--

local function printme(q, conn)
    local uid = q.uid
    local tag = id2tag(q.id_tag)
    local y,m,d = uid:match'^(%d+)-(%d+)-(%d+)'

    local fields = hd.args{clave='clave',precio='precio',qty='qty',rea='rea',totalCents='totalCents'} -- XXX if factura, venta then add: desc='desc', prc='prc'

    local function fetch(w)
	local p = pid2name(tonumber(uid:match'(%d+)$'))

	local ret = {uid=uid, person=p, tag=tag}
	ret.datos = fd.reduce( w.args, fd.map(fields), fd.map(precio(conn)), fd.into, {} )
	ret.total = string.format('%.2f', w.totalCents/100)

	return ret
    end

    return function() lpr( tkt( fetch(q) ) ) end
end

--

local function tickets( conn )
    local tbname = 'tickets'
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = { uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7 }
    local clause = string.format("WHERE uid LIKE '%s%%'", today)
    local query = "SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE '%s%%' GROUP BY uid||id_tag" -- id_tag CHANGES
    local QRY = string.format('SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q %s GROUP BY uid', tbname, clause)

    assert( conn.exec( string.format(sql.newTable, tbname, schema) ) )

-- XXX input is not parsed to Number
    function MM.tickets.add( w )
	local uid = os.date('%FT%TP', ex.now()) .. w.pid
	fd.reduce( w.args, fd.map( hd.args(keys, uid, w.id_tag) ), sql.into( tbname ), conn ) -- ids( uid, w.id_tag ), 
	local a = fd.first( conn.query(string.format(query, tbname, uid)), function(x) return x end )
	w.uid = uid; w.totalCents = a.totalCents; w.count = a.count
	safe(printme(w, conn), 'Tring to print, but ...') -- TRYING OUT
	return w
    end

--- XXX fd.split for count > 50
    function MM.tickets.sse()
	if conn.count( tbname, clause ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(string.format(query, tbname, today)), fd.map(asJSON), fd.into, {} ), ',\n'), event='feed' } end
    end

    return conn
end

--

local function tabs( conn )
    local tabs = {}
--    local m = 0

    function MM.tabs.add( w, q )
	local j = q:find'args'
	w.query = q:sub(j):gsub('args=', '')
	tabs[w.pid] = {pid=w.pid, query=w.query}
--	m = m + 1
	return w
    end

    function MM.tabs.remove( pid ) tabs[pid] = nil end
	--	m = m - 1

    function MM.tabs.sse()
	if #tabs == 0 then return ':empty\n\n' -- m == 0
	else return sse{ data=table.concat( fd.reduce(fd.keys(tabs), fd.map(asJSON), fd.into, {} ), ',\n'), event='tabs' } end
    end

    return conn
end


-- Clients connect to port 8080 for SSE: caja & ventas
local function streaming()
    local srv = assert( socket.bind('*', 8080) )
    local skt = srv:getsockname()
    srv:settimeout(0)
    servers[1] = srv
    print(skt, 'listening on port 8080\n')

    local cts = {}

    local function initFeed( c )
	local ret = true -- c:send(string.format('event: week\ndata: %q\n\n', week))
	for _,feed in pairs(MM) do
	    if ret and feed.sse then ret = ret and c:send( feed.sse() ) end
	end
	return ret
    end

    local function connect2stream()
	local c = srv:accept()
	if c then
	c:settimeout(1)
	local ip = c:getpeername():match'%g+' --XXX ip should be used
	print(ip, 'connected on port 8080 to', skt)
	local response = hd.response({content='stream', body='retry: 60'}).asstr()
	if c:send( response ) and initFeed(c) then cts[#cts+1] = c
	else c:close() end
	end
    end

    servers[srv] = connect2stream

    -- Messages are broadcasted using SSE with different event names.
    function MM.streaming.broadcast( msg )
	if #cts > 0 then
	    cts = fd.reduce( cts, fd.filter( function(c) return c:send(msg) or (c:close() and nil) end ), fd.into, {} )
	end
    end

    return true
end

-- Clients communicate to server using port 8081. id_tag help to sort out data
local function recording()
    local srv = assert( socket.bind('*', 8081) )
    local skt = srv:getsockname()
    srv:settimeout(0)
    servers[2] = srv
    print(skt, 'listening on port 8081\n')

    local function classify( w, q )
	local tag = id2tag(w.id_tag)
	if tag == 'guardar' then MM.tabs.add( w, q ); w.event = 'tabs'; return w end
--	if tag == 'h' then  local m = MM.entradas.add( w ); m.event = 'entradas'; return m end
	if tag == 'd' then MM.tabs.remove(w.pid); w.ret = { 'event: delete\ndata: '.. w.pid ..'\n\n' }; w.event = 'none' w.data = ''; return w end
    -- ELSE: printing: 'a', 'b', 'c'
	w.ret = { 'event: delete\ndata: '.. w.pid ..'\n\n' }
	MM.tickets.add( w ); w.event = 'feed'; return w
    end

    local function add( q )
	local w = hd.parse( q )
--XXX	if w.pid == 0 then return nil end -- IN-CASE Browser sends 'nobody'
--	w.id_tag = tonumber(w.id_tag)
	w = classify(w, q)
	w.args = nil -- sanitize
	return w
    end

    -- Hear for incoming connections and broadcast when needed
    local function listen2talk()
	local c = srv:accept()
	if c then
	c:settimeout(1)
	local ip = c:getpeername():match'%g+'
	print(ip, 'connected on port 8081 to', skt)
	local head, e = c:receive()
	if e then print('Error:', e)
	else
	    local url, qry = head:match'/(%g+)%?(%g+)'
	    repeat head = c:receive() until head:match'^Origin:'
	    local msg = (url:match'update') and sse( MM.cambios.add( hd.parse( qry ) ) ) or sse( add( qry ) )
	    ip = head:match'^Origin: (%g+)'
	    c:send( hd.response({ip=ip, body='OK'}).asstr() )
	    MM.streaming.broadcast( msg )
	end
	c:close()
	end
    end

    servers[srv] = listen2talk

    return true
end

--

fd.comp{ recording, streaming, cambios, tickets, tabs, init, sql.connect( dbname ) }

ex.version( ups )
print('Version: ', ups.vers, 'Week: ', ups.week, '\n')

while 1 do
    local ready = socket.select(servers)
    for _,srv in ipairs(ready) do safe( servers[srv] ) end
end

