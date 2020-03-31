#! /usr/bin/env lua53

-- Import Section
--

local fd	  = require'carlos.fold'

local urldecode   = require'carlos.ferre'.urldecode
local newUID	  = require'carlos.ferre'.newUID
local asnum	  = require'carlos.ferre'.asnum
local aspath	  = require'carlos.ferre'.aspath
local now	  = require'carlos.ferre'.now
local asJSON	  = require'json'.encode
local fromJSON	  = require'json'.decode
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

local sql	  = require'carlos.sqlite'

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local format	  = string.format
local concat	  = table.concat
local remove	  = table.remove
local tointeger	  = math.tointeger

local assert	  = assert
local print	  = print
local pcall	  = pcall
local tostring	  = tostring
local tonumber	  = tonumber

local HOY	  = os.date('%d-%b-%y', now())

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM  = 'ipc://downstream.ipc' --  
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

local ISTKT 	  = {ticket=true, presupuesto=true} -- tabs=true
local TOLL	  = {costo=true, impuesto=true, descuento=true, rebaja=true}
local DIRTY	  = {clave=true, tbname=true, fruit=true}
local ISSTR	  = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local QRY	  = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local UPQ	  = 'UPDATE %q SET %s %s'
local COSTOL 	  = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

local PRECIOS	  = sql.connect':inmemory:'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function found(a, b) return fd.first(fd.keys(a), function(_,k) return b[k] end) end

local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat(v, k)
    local vv = smart(v, k)
    return format('%s = %s', k, vv)
end

local function byDesc(conn, s)
    local qry = format(QDESC, s:gsub('*', '%%')..'%%')
    local o = fd.first(conn.query(qry), function(x) return x end) or {clave=''} -- XXX can return NIL
    return o.clave
end

local function byClave(conn, s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    local o = fd.first(conn.query(qry), function(x) return x end)
    return o and asJSON( o ) or ''
end

local function queryDB(msg)
    if msg:match'desc' then
	local ret = msg:match'desc=([^!]+)'
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

local function process(uid, tag)
    return function(q)
	local o = {uid=uid, tag=tag}
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

local function asTicket(cmd, uid, msg)
    remove(msg, 1)
    return fd.reduce(msg, fd.map(urldecode), fd.map(process(uid, cmd)), fd.into, {cmd})
end

local function receive(skt, a)
    return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()


local server = assert(CTX:socket'PULL')

assert(server:connect( DOWNSTREAM ))

print('Successfully connected to:', DOWNSTREAM, '\n')

-- -- -- -- -- --
--

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'TASKS01' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

-- -- -- -- -- --
--

do
    local path = aspath'ferre'
    PRECIOS.exec(format('ATTACH DATABASE %q AS ferre', path))
    PRECIOS.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos'
    PRECIOS.exec'DETACH DATABASE ferre'
    PRECIOS.exec'CREATE VIEW precios AS SELECT clave, desc, fecha, u1, ROUND(prc1*costol/1e4,2) precio1, u2, ROUND(prc2*costol/1e4,2) precio2, u3, ROUND(prc3*costol/1e4,2) precio3, PRINTF("%d", costol) costol, uidSAT, proveedor, uidPROV FROM datos'
end


---[[ -- -- -- -- --
--

local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')

--
--]] -- -- -- -- --
--

tasks:send_msg'OK'

while true do
print'+\n'

    pollin{server}

	    local msg, more = server:recv_msg()
	    local cmd = msg:match'%a+'
	    local pid = msg:match'pid=([%d%a]+)'

	    if more then
		msg = receive(server, {msg})
		print(concat(msg, '&'), '\n')
	    else
		print(msg, '\n')
	    end

	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if cmd == 'bixolon' then

	    elseif cmd == 'update' then
		tasks:send_msg( format('update %s', updateOne(PRECIOS, msg)) )

	    elseif cmd == 'query' then
		local fruit = msg:match'fruit=(%a+)'
		msgr:send_msg( format('%s query %s', fruit, queryDB(msg)) )

	    else
		if more then

		    if ISTKT[cmd] then
	 		local uid = newUID()..pid
			msg = asTicket(cmd, uid, msg)
		    end

		    tasks:send_msgs( msg )

		else tasks:send_msg( msg ) end

	    end

end


--[[
	elseif tasks:events() == 'POLLIN' then

	    local msg, more = tasks:recv_msg()
	    local cmd = msg:match'%a+'

	    if more then
		msg = receive(tasks, {msg})
		print(concat(msg, '&'), '\n')
	    else
		print(msg, '\n')
	    end

	    if cmd == 'update' then  end -- print( updateOne(PRECIOS, msg) )

	end
--]]
