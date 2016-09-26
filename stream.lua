#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local mx = require'ferre.timezone'

--local function mx() return os.time() - 18000 end

local hoy = os.date('%d-%b-%y', mx())
local today = os.date('%F', mx())
local week = os.date('W%U', mx())
local dbname = string.format('/db/%s.db', week)
local fdbname = '/db/ferre.db'

local MM = {caja={}, tickets={}, tabs={}, entradas={}, cambios={}, recording={}, streaming={}}

local function safe(f)
    local ok,err = pcall(f)
    if not ok then print('Error: \n', err); return false end
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
    return conn
end

local function cambios()
    local conn = sql.connect( fdbname )
    print('Connected to DB', fdbname, '\n')

-- IT DOESN'T PRINT HERE
    function MM.tickets.addDescPrc( w )
	local j = w.precio:sub(-1)
	local qry = string.format('SELECT desc, precio%d ||"/"|| IFNULL(u%d,"?") prc FROM precios WHERE clave LIKE %q', j, j, w.clave)
	local a = fd.first( conn.query(qry), function(x) return x end )
	w.desc = a.desc; w.prc = a.prc;
	return w
    end

    local costol = 'UPDATE %q SET costol = costo*(100+impuesto)*(100-descuento), fecha = %q %s'

    local function reformat(v, k)
	local vv = (k == 'desc' or k == 'fecha' or k:match'^u') and string.format("'%s'", v) or (math.tointeger(v) or tonumber(v) or 0)
	return k .. ' = ' .. vv
    end

    function MM.cambios.add( w )
	local clave = w.clave
	local tbname = w.tbname
	local vwname = w.vwname
	local clause = string.format('WHERE clave LIKE %q', clave)
	local obs = w.obs and (#w.obs > 0) and w.obs

	w.id_tag = nil; w.args = nil; w.clave = nil; w.tbname = nil; w.vwname = nil; w.obs = nil;

	local ret = fd.reduce( fd.keys(w), fd.map( reformat ), fd.into, {} )
	local qry = string.format('UPDATE %q SET %s %s', tbname, table.concat(ret, ', '), clause)
	assert( conn.exec( qry ) ) --, 'Error executing: ' .. qry

	if w.costo or w.impuesto or w.descuento then
	    w.costo = nil; w.impuesto = nil; w.descuento = nil; w.fecha = hoy;
	    qry = string.format(costol, tbname, w.fecha, clause)
	    assert( conn.exec( qry ), 'Error executing: ' .. qry )
	    qry = string.format('SELECT * FROM %q %s', vwname, clause)
	    ret = fd.first( conn.query( qry ), function(x) return x end )
	    fd.reduce( fd.keys(ret), fd.filter(function(x,k) return k:match'^precio' end), fd.merge, w )
	end

--[[
	if obs then -- UPDATE faltantes c/ categorias
--	    qry = string.format("INSERT INTO categorias VALUES ('%s', '%s')", clave, obs)
--	    print(qry)
--	    assert(conn.exec(qry), 'Error executing INSERT INTO categorias')
	    fd.reduce({{clave, (obs:gsub('"','\"'))}}, sql.into'categorias', conn)
		print('Done with insert statement')
	    qry = string.format('SELECT obs FROM categorias WHERE clave LIKE %q', clave)
	    ret = fd.reduce( conn.query(qry), fd.map(function(x) return string.format("'%s'", x.obs) end), fd.into, {} )
		print('Done with obs selection')
	    w.obs = string.format('[%s]', table.concat(ret, ', ')) -- XXX
        end
--]]

	qry = string.format('UPDATE cambios SET version = version + 1, fecha = %q %s', hoy, clause)
	assert( conn.exec( qry ), 'Error executing: ' .. qry )
	w.clave = clave

	return w
--	clause = string.format('WHERE cambios.clave = %q AND cambios.clave = %s.clave', clave, vwname)
--	qry = string.format('SELECT * FROM %q, cambios %s', vwname, clause)
--	return fd.first( conn.query( qry ), function(x) return x end )
    end

    function MM.cambios.sse( w )
	local clause = string.format('WHERE version > 0 AND fecha LIKE %q', hoy) -- XXX
	local qry = string.format('SELECT clave FROM cambios %s', clause)
	local qry2 = string.format('SELECT * FROM faltantes, precios WHERE precios.clave = faltantes.clave AND precios.clave IN (%s)', qry)

	if conn.count( 'cambios', clause ) == 0 then return ':empty\n\n'
	else  return sse{ data=table.concat( fd.reduce(conn.query(qry2), fd.map(asJSON), fd.into, {} ), ',\n'), event='update' } end
    end
end

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

--
local function tickets( conn )
    local tbname = 'tickets'
    local vwname = 'caja'
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = { uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7 }
    local stmt = string.format('AS SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE %q GROUP BY uid', tbname, today..'%')
    local query = 'SELECT * FROM ' .. vwname

    conn.exec( string.format(sql.newTable, tbname, schema) )
    conn.exec( string.format('DROP VIEW IF EXISTS %q', vwname) )
    conn.exec( string.format('CREATE VIEW IF NOT EXISTS %q %s', vwname, stmt) )

    local function collect( q )
	local t = { '', '' } -- uid & id_tag
	for k,v in q:gmatch'([^|]+)|([^|]+)' do if keys[k] then t[keys[k]] = v end end
	return t
    end

    local function ids( uid, tag ) return fd.map( function(t) t[1] = uid; t[2] = tag; return t end ) end

    local function subTotal( w )
	w.subTotal = string.format( '%.2f', w.totalCents / 100 )
	return w
    end
    local function asTable( s )
	local t = {}
	for k,v in s:gmatch'([^|]+)|([^|]+)' do t[k] = v end
	return t
    end
    local tkt = require'ferre.ticket'
    local lpr = require'ferre.bixolon'
    local function forPrinting( w )
	w.total = string.format( '%.2f', w.totalCents / 100 )
	w.fecha = w.uid:match'([^P]+)P'
	w.datos = fd.reduce( w.args, fd.map( asTable ), fd.map( MM.tickets.addDescPrc ), fd.map( subTotal ), fd.into, {} )
        lpr( tkt( w ) )
	w.datos = nil
    end

-- XXX input is not parsed to Number
    function MM.tickets.add( w )
	local uid = os.date('%FT%TP', mx()) .. w.pid
	fd.reduce( w.args, fd.map( collect ), ids( uid, w.id_tag ), sql.into( tbname ), conn )
	local a = fd.first( conn.query(string.format('%s WHERE uid = %q ', query, uid)), function(x) return x end )
	w.uid = uid; w.totalCents = a.totalCents; w.count = a.count
	forPrinting( w )
	MM.tabs.remove( w.pid )
	return w
    end

    function MM.tickets.sse()
	if conn.count( vwname ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(query), fd.map(asJSON), fd.into, {} ), ',\n'), event='feed' } end
    end

    return conn
end

--
local function tabs( conn )
    local tbname = 'tabs'
    local schema = 'pid INTEGER PRIMARY KEY, query' -- 'clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = { pid=1, query=2 } -- clave=2, precio=3, qty=4, rea=5, totalCents=6 }
    local query = 'SELECT * FROM ' .. tbname

    conn.exec( string.format(sql.newTable, tbname, schema) )
    conn.exec( string.format('DELETE FROM %q', tbname ) )

    function MM.tabs.add( w, q )
	local j = q:find'args'
	w.query = q:sub(j):gsub('args=', '')
	local vals = string.format('%d, %q', w.pid, w.query)
	conn.exec( string.format("INSERT INTO %q VALUES( %s )", tbname, vals) )
	return w
    end

    function MM.tabs.remove( pid )
	conn.exec( string.format("DELETE FROM %q WHERE pid = %d", tbname, pid) )
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
	local ret = c:send(string.format('event: week\ndata: %q\n\n', week))
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
	if tag == 'h' then  local m = MM.entradas.add( w ); m.event = 'entradas'; return m end
	if tag == 'd' then w.ret = { 'event: delete\ndata: '.. w.pid ..'\n\n' }; w.event = 'none' w.data = ''; return w end
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

fd.comp{ cambios, recording, streaming, tickets, tabs, entradas, init, sql.connect( dbname ) }

while 1 do
--    safe( MM.streaming.connect )
    MM.streaming.connect()
--    MM.recording.talk()
    safe( MM.recording.talk )
end
