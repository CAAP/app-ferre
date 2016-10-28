#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local mx = require'ferre.timezone'

local hoy = os.date('%d-%b-%y', mx())
local today = os.date('%F', mx())
local week = os.date('W%U', mx())
local dbname = string.format('/db/%s.db', week)
local fdbname = '/db/ferre.db'

local MM = {tickets={}, tabs={}, entradas={}, cambios={}, recording={}, streaming={}}

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
    return conn
end

local function cambios( conn )
    local tbname = 'updates'
    local schema = 'vers INTEGER PRIMARY KEY, clave, campo, valor'
--    local keys = { vers=1, clave=2, campo=3 }
    local query = "SELECT max(vers) vers FROM "..tbname

    assert( conn.exec( string.format(sql.newTable, tbname, schema) ) )

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
	ret = fd.first( conn.query(string.format('SELECT clave, costol FROM datos %s', clause)), function(x) return x end )
	w.ret = ret --{ string.format('event: costo\n%s\n\n', asJSON(ret)) }
    end

    local function up_precios(w, clause)
	local ps = fd.reduce( fd.keys(w), fd.filter(function(_,k) return k:match'^prc' end), fd.map(function(_,k) return k end), fd.into, {} )
	for i=1,#ps do local k = ps[i]; w[k] = nil; ps[i] = k:gsub('prc','precio') end
	local ret = fd.first( conn.query(string.format('SELECT %s FROM precios %s', table.concat(ps, ', '), clause)), function(x) return x end )
	fd.reduce( fd.keys(ret), fd.merge, w )
    end

-- XXX ALL can be based on updates instead !!! XXX

    function MM.cambios.add( w )
	local clave = w.clave
	local tbname = w.tbname
	local clause = string.format('WHERE clave LIKE %q', clave)

	w.id_tag = nil; w.args = nil; w.clave = nil; w.tbname = nil;

	if w.desc then w.desc = w.desc:upper() end

	local ret = fd.reduce( fd.keys(w), fd.map( reformat ), fd.into, {} )
	local qry = string.format('UPDATE %q SET %s %s', tbname, table.concat(ret, ', '), clause)
	assert( conn.exec( qry ), qry )

	if w.costo or w.impuesto or w.descuento then up_costos(w, clause) end

	if w.prc1 or w.prc2 or w.prc3 then up_precios(w, clause) end

	fd.reduce( fd.keys(w), fd.map(function(v,k) return {'', clave, k=='ret' and 'costol' or k, k=='ret' and v.costol or v} end), sql.into'updates', conn)

	w.ret = w.ret and { string.format('event: costo\n%s\n\n', asJSON(w.ret)) }

	w.clave = clave

	return w
    end
end

--
local function tickets( conn )
    local tbname = 'tickets'
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = { uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7 }
    local query = "SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE '%s%%' GROUP BY uid"

    assert( conn.exec( string.format(sql.newTable, tbname, schema) ) )

-- XXX input is not parsed to Number
    function MM.tickets.add( w )
	local uid = os.date('%FT%TP', mx()) .. w.pid
	fd.reduce( w.args, fd.map( hd.args(keys, uid, w.id_tag) ), sql.into( tbname ), conn ) -- ids( uid, w.id_tag ), 
	local a = fd.first( conn.query(string.format(query, tbname, uid)), function(x) return x end )
	w.uid = uid; w.totalCents = a.totalCents; w.count = a.count
	return w
    end

    function MM.tickets.sse()
	if conn.count( tbname, clause ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(string.format(query, tbname, today)), fd.map(asJSON), fd.into, {} ), ',\n'), event='feed' } end
    end

    return conn
end

--
local function tabs( conn )
    local tbname = 'tabs'
    local schema = 'pid INTEGER PRIMARY KEY, query' -- 'clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = { pid=1, query=2 } -- clave=2, precio=3, qty=4, rea=5, totalCents=6 }
    local query = 'SELECT * FROM ' .. tbname

    assert( conn.exec( string.format(sql.newTable, tbname, schema) ) )
    assert( conn.exec( string.format('DELETE FROM %q', tbname ) ) )

    function MM.tabs.add( w, q )
	local j = q:find'args'
	w.query = q:sub(j):gsub('args=', '')
	local vals = string.format('%d, %q', w.pid, w.query)
	assert( conn.exec( string.format("INSERT INTO %q VALUES( %s )", tbname, vals) ) )
	return w
    end

    function MM.tabs.remove( pid )
	assert( conn.exec( string.format("DELETE FROM %q WHERE pid = %d", tbname, pid) ) )
    end

    function MM.tabs.sse()
	if conn.count( tbname ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(query), fd.map(asJSON), fd.into, {} ), ',\n'), event='tabs' } end
    end

    return conn
end


-- Clients connect to port 8080 for SSE: caja & ventas
local function streaming()
    local srv = assert( socket.bind('*', 8080) )
    srv:settimeout(1)
    print'Listening on port 8080\n'

    local cts = {}

    local function init( c )
	local ret = true -- c:send(string.format('event: week\ndata: %q\n\n', week))
	for _,feed in pairs(MM) do
	    if ret and feed.sse then ret = ret and c:send( feed.sse() ) end
	end
	return ret
    end

    function MM.streaming.connect()
	local c = srv:accept()
	if c then
	    c:settimeout(1)
	    local ip = c:getpeername():match'%g+' --XXX ip should be used
	    local response = hd.response({content='stream', body='retry: 60'}).asstr()
	    if c:send( response ) and init(c) then cts[#cts+1] = c
	    else c:close() end
	    print('Connected on port 8080 to:', ip)
	end
    end

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
    srv:settimeout(1)
    print'Listening on port 8081\n'

    local function classify( w, q )
	local tag = w.id_tag
	if tag == 'u' then local m = MM.cambios.add( w ); m.event = m.faltante and 'faltante' or 'update'; return m end
	if tag == 'g' then MM.tabs.add( w, q ); w.event = 'tabs'; return w end
--	if tag == 'h' then  local m = MM.entradas.add( w ); m.event = 'entradas'; return m end
	if tag == 'd' then MM.tabs.remove(w.pid); w.ret = { 'event: delete\ndata: '.. w.pid ..'\n\n' }; w.event = 'none' w.data = ''; return w end
    -- printing: 'a', 'b', 'c'
	w.ret = { 'event: delete\ndata: '.. w.pid ..'\n\n' }
	MM.tickets.add( w ); w.event = 'feed'; return w
    end

    local function add( q )
	local w = hd.parse( q )
	w = classify(w, q)
	w.args = nil -- sanitize
	return w
    end

    -- Hear for incoming connections and broadcast when needed
    function MM.recording.talk()
	local c = srv:accept()
	if c then
	    local ip = c:getpeername():match'%g+'
	    local head, e = c:receive()
	    if not e then
		local url, qry = head:match'/(%g+)%?(%g+)'
		repeat head = c:receive() until head:match'^Origin:'
		local msg = sse( add( qry ) )
		ip = head:match'^Origin: (%g+)'
		c:send( hd.response({ip=ip, body='OK'}).asstr() )
--		local msg = (url == 'update') and sse( cambios() ) or sse( add( qry ) ) -- intoDB
		MM.streaming.broadcast( msg )
	    end
	    c:close()
	end
    end

    return true
end

--

fd.comp{ recording, streaming, cambios, tickets, tabs, init, sql.connect( dbname ) }

while 1 do
--    safe( MM.streaming.connect )
    MM.streaming.connect()
    safe( MM.recording.talk )
end


--[[
	if obs then -- UPDATE faltantes c/ categorias
	    qry = string.format("INSERT INTO categorias VALUES ('%s', '%s')", clave, obs)
	    assert(conn.exec(qry), 'Error executing INSERT INTO categorias')
	    qry = string.format('SELECT obs FROM categorias WHERE clave LIKE %q', clave)
	    ret = fd.reduce( conn.query(qry), fd.map(function(x) return string.format("'%s'", x.obs) end), fd.into, {} )
	    w.obs = string.format('[%s]', table.concat(ret, ', ')) -- XXX
        end
--]]


--[[
local function entradas( conn )
    local tbname = 'entradas'
    local vwname = 'horas'
    local schema = 'uid, tag'
    local stmt = string.format('AS SELECT * FROM %q WHERE uid LIKE %q GROUP BY uid', tbname, today..'%')
    local query = string.format('SELECT * FROM %q', vwname)

    conn.exec( string.format(sql.newTable, tbname, schema) )
    conn.exec( string.format('DROP VIEW IF EXISTS %q', vwname) )
    conn.exec( string.format('CREATE VIEW IF NOT EXISTS %q %s', vwname, stmt ) )

    local function reformat(w) return { pid=w.uid:match'%d+$', hora=w.uid:match'T(%d+:%d+)', tag=w.tag } end

    function MM.entradas.add( w )
	local uid = os.date('%FT%TP', mx()) .. w.pid
	w.uid = uid
	conn.exec( string.format('INSERT INTO %q VALUES(%q, %q)', tbname, uid, w.tag) )
	return reformat( w )
    end

    function MM.entradas.sse()
	if conn.count( vwname ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(query), fd.map(reformat), fd.map(asJSON), fd.into, {} ), ',\n'), event='entradas' } end
    end

    return conn
end
--]]


