#!/usr/local/bin/lua

local socket = require"socket"
local fd = require'carlos.fold'
local hd = require'ferre.header'
local sql = require'carlos.sqlite'
local ex = require'ferre.extras'
local tkt = require'ferre.ticket'
local lpr = require'ferre.bixolon'

local week = ex.week() -- os.date('Y%YW%U', mx())
local dbname = string.format('/db/%s.db', week)

local MM = {tickets={}, tabs={}, entradas={}, cambios={}, recording={}, streaming={}}

local changes = require'cambios' -- XXX change to "ferre.cambios"
local tickets = require'tickets' -- XXX change to "ferre.tickets"

local servers = {}

-------------------
-------------------

local function safe(f, msg)
    local ok,err = pcall(f)
    if not ok then print('Error: \n', msg or '',  err); return false end
end

local function asJSON(w) return string.format('data: %s', hd.asJSON(w)) end

local function asSSE(tb, ev) return {data=table.concat(fd.reduce(tb, fd.map( asJSON ), fd.into, {}), ',\n'), event=ev}

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

	------- CAMBIOS ---------
    cambios.init( conn )

    function MM.cambios.sse() return sse{data=asJSON(changes.sse()), event='update'} end

    function MM.cambios.add( w ) return asSSE( fd.keys(changes.add(conn, w)), 'update' ) end
	------------------------

	------- TICKETS ---------
    tickets.init( conn )

    function MM.tickets.sse()
	local any, msg = tickets.sse( conn )
	if any then return sse(asSSE(msg,'feed'))
	else return msg end
    end

    function MM.tickets.add(w)
	local txt = tickets.add(conn, w)
	safe(function() lpr( tkt( txt ) ) end, 'Tring to print, but ...') -- TRYING OUT --
	return w
    end
	-------------------------

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

