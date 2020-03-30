#! /usr/bin/env lua53

-- Import Section
--

local fd	  = require'carlos.fold'

local urldecode   = require'carlos.ferre'.urldecode
local newUID	  = require'carlos.ferre'.newUID
local asnum	  = require'carlos.ferre'.asnum
local aspath	  = require'carlos.ferre'.aspath
local asJSON	  = require'json'.encode
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

local sql	  = require'carlos.sqlite'

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local assert	  = assert
local format	  = string.format
local concat	  = table.concat
local remove	  = table.remove

local print	  = print

--local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM  = 'ipc://downstream.ipc' --  
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

local ISTKT 	  = {ticket=true, presupuesto=true} -- tabs=true

local QRY	  = 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'

local PRECIOS	  = sql.connect':inmemory:'

--------------------------------
-- Local function definitions --
--------------------------------
--

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
    PRECIOS.exec'CREATE TABLE precios AS SELECT * FROM ferre.precios'
    PRECIOS.exec'DETACH DATABASE ferre'
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
