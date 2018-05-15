#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local hd = require'ferre.header'
local ex = require'ferre.extras'
local tkt = require'ferre.ticket'
local lpr = require'ferre.bixolon'

local week = ex.week() -- os.date('Y%YW%U', mx())
local dbname = string.format('/db/%s.db', week)

local MM = {tickets={}, tabs={}, entradas={}, cambios={}, recording={}, streaming={}}

local changes = {} -- require'ferre.cambios' -- XXX change to "ferre.cambios"
local tickets = require'ferre.tickets' -- XXX change to "ferre.tickets"

local servers = {}

do
local hoy = os.date('%d-%b-%y', ex.now())
local ups = {week=week, vers=0, store='VERS', prevs=-1}
local isstr = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true}

local function reformat(v, k)
    local vv = isstr[k] and string.format("'%s'", v:upper()) or (math.tointeger(v) or tonumber(v) or 0)
    return k .. ' = ' .. vv
end

local function precios(conn, w, clause, f)
    local qry = string.format('SELECT * FROM precios %s', clause)
    local ret = fd.first( conn.query(qry), function(x) return x end )
    fd.reduce( fd.keys(precios(clause)), fd.filter(f), fd.merge, w )
end

local function up_costos(conn, w, clause)
    local costol = 'UPDATE datos SET costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100), fecha = %q %s'

    w.costo = nil; w.impuesto = nil; w.descuento = nil; w.fecha = hoy;

    local qry = string.format(costol, w.fecha, clause)
    assert( conn.exec( qry ), 'Error executing: ' .. qry )
    w.faltante = 0
    qry = string.format('UPDATE faltantes SET faltante = 0 %s', clause)
    assert(conn.exec(qry), 'Error executing: ' .. qry)

    -- VIEW precios is necessary to produce precio1, precio2, etc
    precios( conn, w, clause, function(_,k) return k:match'^precio' end )
	-- in order to update costo in admin.html
    w.costol = fd.first( conn.query(string.format('SELECT costol FROM datos %s', clause)), function(x) return x end ).costol
end

local function up_precios(w, clause)
    local ps = fd.reduce( fd.keys(w), fd.filter(function(_,k) return k:match'^prc' end), fd.rejig(function(_,k) return true,k:gsub('prc','precio') end), fd.merge, {} )

    w.prc1 = nil; w.prc2 = nil; w.prc3 = nil;

    precios( w, clause, function(_,k) return ps[k] end )
end

function changes.add( conn, w )
	local clave = w.clave
	local tbname = w.tbname
	local clause = string.format('WHERE clave LIKE %q', clave)

	w.id_tag = nil; w.args = nil; w.clave = nil; w.tbname = nil; -- SANITIZE

	local ret = fd.reduce( fd.keys(w), fd.map( reformat ), fd.into, {} )
	local qry = string.format('UPDATE %q SET %s %s', tbname, table.concat(ret, ', '), clause)
	assert( conn.exec( qry ), qry )

	if w.costo or w.impuesto or w.descuento or w.rebaja then up_costos(conn, w, clause) end

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

	return ret
end

function changes.init(conn)
    ex.version( ups )
    print('Version: ', ups.vers, 'Week: ', ups.week, '\n')
    return conn
end

function changes.sse() return ups end -- prev=ups.vers
end

-------------------
-------------------

local function safe(f, msg)
    local ok,err = pcall(f)
    if not ok then print('Error: \n', msg or '',  err); return false end
end

local function asJSON(w) return string.format('data: %s', hd.asJSON(w)) end

local function asSSE(tb, ev) return {data=table.concat(fd.reduce(tb, fd.map( asJSON ), fd.into, {}), ',\n'), event=ev} end

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

-------------------
-------------------

local function init( conn )
    print('Connected to DB', dbname, '\n')
    assert( conn.exec"ATTACH DATABASE '/db/ferre.db' AS FR" )
    assert( conn.exec"ATTACH DATABASE '/db/inventario.db' AS NV" )
    print'\nSuccessfully connected to DBs ferre, inventario.\n'


	------- TICKETS ---------
    if not(conn.exists'tickets') then
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    assert( conn.exec( string.format(sql.newTable, 'tickets', schema) ) )
    end
    tickets.init( conn )

    function MM.tickets.sse()
	local any, msg = tickets.sse( conn )
	if any then return sse(asSSE(msg,'feed'))
	else return msg end
    end

    -- XXX change it, such that, this fn returns ok, PID, in case of success, and the GUI calls print afterwards.
    -- thus, change public/app.js as well XXX
    function MM.tickets.add(w)
	local txt = tickets.add(conn, w)
	safe(function() lpr( tkt( txt ) ) end, 'Tring to print, but ...') -- TRYING OUT --
	return w
    end
	-------------------------


	------- CAMBIOS ---------
    if not(conn.exists'updates') then
    local schema = 'vers INTEGER PRIMARY KEY, clave, campo, valor'
    assert( conn.exec( string.format(sql.newTable, 'updates', schema) ) )
    end
    changes.init( conn ) 

    function MM.cambios.sse() return sse{data=asJSON(changes.sse()), event='update'} end

    function MM.cambios.add( w ) return asSSE( fd.keys(changes.add(conn, w)), 'update' ) end
	------------------------


    return conn
end

--

local function tabs( conn )
    local tabs = {}

    function MM.tabs.add( w, q )
--	w.query = hd.asJSON(fd.reduce(w.args, fd.map(hd.args(keys)), fd.into, {})):gsub('^{', '['):gsub('}$',']')
	local j = q:find'args'
	w.query = q:sub(j):gsub('args=', '')
	tabs[w.pid] = {pid=w.pid, query=w.query}
	return w
    end

    function MM.tabs.remove( pid ) tabs[pid] = nil end

    function MM.tabs.sse()
	if pairs(tabs)(tabs) then return sse(asSSE(fd.keys(tab), 'tabs'))
	else return ':empty\n\n' end
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

fd.comp{ recording, streaming, tabs, init, sql.connect( dbname ) } -- tickets, cambios 

while 1 do
    local ready = socket.select(servers)
    for _,srv in ipairs(ready) do safe( servers[srv] ) end
end

