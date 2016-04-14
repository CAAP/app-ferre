#!/bin/ferre/lua

local socket = require"socket"

local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'

local tbname = os.date'W%U'

local MM = {caja={}, tickets={}, recording={}, streaming={}}

local function asJSON( w )
    local ret = {}
    for k,v in pairs(w) do
	ret[#ret+1] = string.format('%q: %q', k, math.tointeger(v) or v)
    end
    return string.format('data: {%s}', table.concat(ret, ', '))
end

local function sse( data )
    local ret = {'event: feed', 'data: ['}
    ret[#ret+1] = data
    ret[#ret+1] = 'data: ]'
    ret[#ret+1] = '\n'
    return table.concat( ret, '\n')
end

local function caja()
    local dbname = '/db/caja.sql'
    local schema = 'uid PRIMARY KEY, count INTEGER, id_tag'

    local conn = sql.connect( dbname )
    conn.exec( string.format(sql.newTable, tbname, schema) )
    print('Connected to DB', dbname, '\n')

    local clause = 'WHERE id_tag NOT LIKE "%Z"'
    local query = string.format('SELECT * FROM %q %s', tbname, clause )

    function MM.caja.sse()
	if conn.count( tbname, clause ) == 0 then return ':empty\n\n'
	else return sse( table.concat( fd.reduce(conn.query(query), fd.map(asJSON), fd.into, {} ), ',\n') ) end
    end

    function MM.caja.add( w )
	local uid = os.date'%FT%TP' .. w.id_person
	local vals = string.format('%q, %d, %q', uid, w.count, w.id_tag)
	local qry = string.format('INSERT INTO %q VALUES(%s)', tbname, vals)
	print( conn.exec( qry ) )
	w.uid = uid
	return w
    end
end

local function tickets()
    local dbname = '/db/tickets.sql'
    local schema = 'uid, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    local keys = {uid=1, clave=2, precio=2, qty=3, rea=4, totalCents=5}

    local conn = sql.connect( dbname )
    conn.exec( string.format(sql.newTable, tbname, schema) )
    print('Connected to DB', dbname, '\n')

    local function collect( q )
	local t = { }
	for k,v in q:gmatch'([^%s]+)%s([^%s]+)' do if keys[k] then t[keys[k]] = v end end
	return t
    end

    local function append( uid ) return fd.map( function(x) x[1] = uid; return x end ) end

    function MM.tickets.add( w )
	fd.reduce( w.args, fd.map( collect ), append( w.uid ), sql.into( tbname ), conn )
	return w
    end
end

local function streaming()
    local srv = assert( socket.bind('*', 8080) )
    srv:settimeout(1)
    print'Listening on port 8080\n'

    local cts = {}

    function MM.streaming.accept()
	local c = srv:accept()
	if c then
	    c:settimeout(1)
	    local ip = c:getpeername():match'%g+'
	    local response = hd.response({content='stream', ip=ip, body='retry: 60'}).asstr()
	    if c:send( response ) and c:send( MM.caja.sse() ) then cts[#cts+1] = c
	    else c:close() end
	    print('Connected to:', ip)
	end
    end

    function MM.broadcast( w )
	if #cts > 0 then
	    local msg = sse( asJSON( w ) )
	    cts = fd.reduce( cts, fd.filter( function(c) return c:send(msg) or (c:close() and nil) end ), fd.into, {} )
	end
    end
end

local function recording()
    local srv = assert( socket.bind('*', 8081) )
    srv:settimeout(1)
    print'Listening on port 8081\n'

    local function add( q )
	local w =  hd.parse( q )
	if not w.args then return {msg='Empty Query'} end
	MM.tickets.add( MM.caja.add( w ) )
	w.msg = 'OK'
	w.args = nil
	return w
    end

    function MM.recording.accept()
	local c = srv:accept()
	if c then
	    local ip = c:getpeername():match'%g+'
	    local head, e = c:receive()
	    if not e then
		local url, qry = head:match'/(%g+)%?(%g+)'
		local w = add( qry )
		c:send( hd.response({ip=ip, body=w.msg}).asstr() )
		if w.msg == 'OK' then MM.broadcast( w ) end
	    end
	    c:close()
	end
    end
end

caja()
tickets()
streaming()
recording()

while 1 do
    MM.streaming.accept()
    MM.recording.accept()
    socket.sleep(2)
end
