#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local mx = require'ferre.timezone'

--local function mx() return os.time() - 18000 end

local today = os.date('%F', mx())
local week = os.date('W%U', mx())
local dawk= string.format('event: week\ndata: %q\n\n', week)
local dbname = string.format('/db/%s.db', week)

local MM = {caja={}, tickets={}, entradas={}, recording={}, streaming={}}

local function asJSON( w )
    local ret = {}
    for k,v in pairs(w) do
	ret[#ret+1] = string.format('%q: %q', k, math.tointeger(v) or v)
    end
    return string.format('data: {%s}', table.concat(ret, ', '))
end

local function sse( w )
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

--
local function people( conn )
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
	local uid = os.date('%FT%TP', mx()) .. w.id_person
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
    local stmt = string.format('AS SELECT uid, COUNT(uid) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE %q GROUP BY uid', tbname, today..'%')
    local query = 'SELECT * FROM ' .. vwname

    conn.exec( string.format(sql.newTable, tbname, schema) )
    conn.exec( string.format('CREATE VIEW IF NOT EXISTS %q %s', vwname, stmt) )

    local function collect( q )
	local t = { '', '' } -- uid & id_tag
	for k,v in q:gmatch'([^%s]+)%s([^%s]+)' do if keys[k] then t[keys[k]] = v end end
	return t
    end

    local function ids( uid, tag ) return fd.map( function(t) t[1] = uid; t[2] = tag; return t end ) end

    function MM.tickets.add( w )
	local uid = os.date('%FT%TP', mx()) .. w.id_person
	fd.reduce( w.args, fd.map( collect ), ids( uid, w.id_tag ), sql.into( tbname ), conn )
	return w
    end

    function MM.tickets.sse()
	if conn.count( vwname ) == 0 then return ':empty\n\n'
	else return sse{ data=table.concat( fd.reduce(conn.query(query), fd.map(asJSON), fd.into, {} ), ',\n'), event='feed' } end
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
	return c:send( dawk ) and c:send( MM.tickets.sse() )
    end

    function MM.streaming.connect()
	local c = srv:accept()
	if c then
	    c:settimeout(1)
	    local ip = c:getpeername():match'%g+'
	    local response = hd.response({content='stream', body='retry: 60'}).asstr()
	    if c:send( response ) and c:send(dawk) and c:send( MM.tickets.sse() ) and c:send( MM.entradas.sse() or '' ) then cts[#cts+1] = c
	    else c:close() end
	    print('Connected on port 8080 to:', ip)
	end
    end

    -- Messages are broadcasted using SSE with different event names.
    function MM.broadcast( w )
	w.args = nil -- sanitize w
	if #cts > 0 then
	    local msg = sse( w )
	    cts = fd.reduce( cts, fd.filter( function(c) return c:send(msg) or (c:close() and nil) end ), fd.into, {} )
	end
    end

    return true
end

local function classify( w, q )
    local tag = w.id_tag
    if tag == 'g' then w.query = q; w.event = 'save'; return w end
    if tag == 'h' then  local m = MM.entradas.add( w ); m.event = 'entradas'; return m end
    -- printing: 'a', 'b', 'c'
    w.ret = { 'event: delete\ndata: '.. w.id_person ..'\n\n' }
    MM.tickets.add( w ); w.event = 'feed'; return w
end

-- Clients communicate to server using port 8081. id_tag help to sort out data
local function recording()
    local srv = assert( socket.bind('*', 8081) )
    srv:settimeout(1)
    print'Listening on port 8081\n'

    local function add( q )
	local w = hd.parse( q )
	if not w.args then return {msg='Empty Query'} end
	w = classify(w, q)
	w.msg = 'OK'
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
		local w = add( qry ) -- data into DB
		repeat head = c:receive() until head:match'^Origin:'
		ip = head:match'^Origin: (%g+)'
		c:send( hd.response({ip=ip, body=w.msg}).asstr() )
		if w.msg == 'OK' then MM.broadcast( w ) end
	    end
	    c:close()
	end
    end

    return true
end

--

fd.comp{ recording, streaming, tickets, people, init, sql.connect( dbname ) }

while 1 do
    MM.streaming.connect()
    MM.recording.talk()
end
