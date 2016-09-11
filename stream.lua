#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local mx = require'ferre.timezone'

local week = os.date('W%U', mx())
local dawk= string.format('event: week\ndata: %q\n\n', week)

--local tbname = os.date'W%U'
local dbname = string.format('/db/%s.db', week)

local MM = {caja={}, tickets={}, recording={}, streaming={}}

local function asJSON( w )
    local ret = {}
    for k,v in pairs(w) do
	ret[#ret+1] = string.format('%q: %q', k, math.tointeger(v) or v)
    end
    return string.format('data: {%s}', table.concat(ret, ', '))
end

-- maybe delete event should be added if needed
local function sse( data, event, pid )
    local ret = {'event: ' .. event, 'data: ['}
    ret[#ret+1] = data
    ret[#ret+1] = 'data: ]'
    ret[#ret+1] = '\n'
    if pid and (pid ~= '0') then ret[#ret+1] = 'event: delete\ndata: '.. pid ..'\n\n' end
    return table.concat( ret, '\n')
end

local function caja( )
    function MM.caja.add( w )
	local uid = os.date('%FT%TP', mx()) .. w.id_person
	local vals = string.format('%q, %d, %q, %q', uid, w.count, w.id_tag, w.rfc or '')
	local qry = string.format('INSERT INTO %q VALUES(%s)', tbname, vals)
	w.uid = uid
	conn.exec( qry )
	return w
    end
end

local function tickets()
    local tbname = 'tickets'
    local vwname = 'caja'
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = {uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7}
    local stmt = 'AS SELECT uid, COUNT(uid) count, SUM(totalCents) totalCents, id_tag FROM '.. tbname ..' GROUP BY uid'
    local query = 'SELECT * FROM ' .. vwname

    local conn = sql.connect( dbname )
    conn.exec( string.format(sql.newTable, tbname, schema) )
    conn.exec( string.format('CREATE VIEW IF NOT EXISTS %q %s', vwname, stmt) )
    print('Connected to DB', dbname, '\n')

    local function collect( q )
	local t = { '', '' } -- random uid & id_tag
	for k,v in q:gmatch'([^%s]+)%s([^%s]+)' do if keys[k] then t[keys[k]] = v end end
	return t
    end

    local function ids( uid, tag ) return fd.map( function(t) t[1] = uid; t[2] = tag; return t end ) end

    function MM.tickets.add( w )
	local uid = os.date('%TP', mx()) .. w.id_person
	fd.reduce( w.args, fd.map( collect ), ids( uid, w.id_tag ), sql.into( tbname ), conn )
	return w
    end

    function MM.tickets.sse()
	if conn.count( vwname ) == 0 then return ':empty\n\n'
	else return sse( table.concat( fd.reduce(conn.query(query), fd.map(asJSON), fd.into, {} ), ',\n'), 'feed' ) end
    end
end

-- Clients connect to port 8080 for SSE: caja & ventas
local function streaming()
    local srv = assert( socket.bind('*', 8080) )
    srv:settimeout(1)
    print'Listening on port 8080\n'

    local cts = {}

    function MM.streaming.connect()
	local c = srv:accept()
	if c then
	    c:settimeout(1)
	    local ip = c:getpeername():match'%g+'
	    local response = hd.response({content='stream', body='retry: 60'}).asstr()
	    if c:send( response ) and c:send(dawk) and c:send( MM.tickets.sse() ) then cts[#cts+1] = c
	    else c:close() end
	    print('Connected on port 8080 to:', ip)
	end
    end

    -- a possible change in sse() might make necessary to add delete_sse() as an extra step

    -- Messages are broadcastes using SSE with different event names.
    function MM.broadcast( w )
	w.args = nil -- sanitize w
	if #cts > 0 then
	    local msg = sse( asJSON( w ), w.query and 'save' or 'feed', w.query and '0' or w.id_person )
	    cts = fd.reduce( cts, fd.filter( function(c) return c:send(msg) or (c:close() and nil) end ), fd.into, {} )
	end
    end
end

-- Clients communicate to server using port 8081. id_tag help to sort out data
local function recording()
    local srv = assert( socket.bind('*', 8081) )
    srv:settimeout(1)
    print'Listening on port 8081\n'

    -- maybe necessary to add id_tag: 'd' when delete events are broadcasted
    local function add( q )
	local w = hd.parse( q )
	if not w.args then return {msg='Empty Query'} end
	if w.id_tag == 'g' then w.query = q
	else MM.tickets.add( w ) end
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
end

tickets()
streaming()
recording()

while 1 do
    MM.streaming.connect()
    MM.recording.talk()
end
