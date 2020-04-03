#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local connect		= require'carlos.sqlite'.connect
local into		= require'carlos.sqlite'.into
local asJSON		= require'json'.encode
local fromJSON		= require'json'.decode
local ticket		= require'carlos.ticket'.ticket

local tabs		= require'carlos.ferre.tabs'
local vers		= require'carlos.ferre.vers'
local feed		= require'carlos.ferre.feed'
local asweek		= require'carlos.ferre'.asweek
local now		= require'carlos.ferre'.now
local aspath		= require'carlos.ferre'.aspath
local uid2week		= require'carlos.ferre'.uid2week

local concat 	= table.concat
local remove	= table.remove
local assert	= assert
local type	= type
local format	= string.format
local print	= print

local WEEK 	= asweek( now() )

--local TODAY

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	 = 'ipc://stream.ipc'
local UPSTREAM	 = 'ipc://upstream.ipc'
local BIXOLON	 = 'ipc://bixolon.ipc'

local TABS	 = { tabs=true, delete=true, msgs=true,
		     pins=true, login=true, CACHE=true }
local VERS	 = { version=true, update=true, CACHE=true }
local FEED	 = { uid=true } -- adjust, feed=true, ledger=true
local PRINT	 = { ticket=true, bixolon=true }

local SUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag, nombre FROM tickets WHERE tag NOT LIKE "factura" GROUP BY uid'
local SLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal, uid FROM tickets'

local QUID	 = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QLPR	 = 'SELECT * FROM lpr WHERE uid LIKE %q'
local QTKT	 = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local INDEX

local DB	= {}

--local TICKETS	= connect':inmemory:'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function receive(skt, a)
    return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a)
end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function mail(fruit, cmd)
    return function(a)
	return format('%s %s %s', fruit, cmd, asJSON(a))
    end
end

local function addDB(week)
    local conn = connect':inmemory:'
    DB[week] = conn
    assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(week))) )
    assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
    assert( conn.exec'DETACH DATABASE week' )
    assert( conn.exec(format('CREATE VIEW uids AS %s', SUID)) )
    assert( conn.exec(format('CREATE VIEW lpr AS %s', SLPR)) )
    return conn
end

local function getConn(uid)
    local week = uid2week(uid)
    return DB[week] or addDB(week)
end

local function header(uid, conn) return fd.first(conn.query(format(QUID, uid)), function(x) return x end) end

local function bixolon(uid, conn)
    local qry = format(QLPR, uid)
    return fd.reduce(conn.query(qry), fd.into, {})
end

local function addAll(msg)
    local uid = fromJSON(msg[1]).uid
    local conn = getConn(uid)
    if #msg > 6 then
	fd.slice(5, msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    else
	fd.reduce(msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', conn)
    end
    return uid, conn
end

local function switch(cmd, msg, send)
    if cmd == 'ticket' then
	remove(msg, 1)
	local uid, conn = addAll(msg)
	local m = header(uid, conn)
	--
	send( format('feed %s', asJSON(m)) )
	return uid, ticket(m, bixolon(uid, conn))
    elseif cmd == 'bixolon' then
	local uid = msg:match'uid=([^!]+)'
	local conn = getConn(uid)
	local m = header(uid, conn)
	--
	return uid, ticket(m, bixolon(uid, conn))
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- -- -- -- -- --
--

do
    local conn = addDB( WEEK )
    INDEX = conn.header'tickets'
    print('items in tickets:', conn.count'tickets', '\n')
end

-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'inmem' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM)

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate( true ) )

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM)
--
-- -- -- -- -- --
--
local printer = assert(CTX:socket'PUSH')

assert( printer:immediate( true ) )

assert( printer:connect( BIXOLON ) )

print('\nSuccessfully connected to:', BIXOLON)
--
-- -- -- -- -- --
--

tasks:send_msg'OK'

--
-- -- -- -- -- --
--

local function send( m ) return msgr:send_msg(m) end

local function deliver( skt ) return function(m, i) skt:send_msg( m ) end end

--
--
-- Run loop
--

while true do
print'+\n'

    pollin{tasks}

    local msg, more = tasks:recv_msg()
    local cmd = msg:match'%a+'
    local pid = msg:match'pid=(%d+)'

    if more then
	msg = receive(tasks, {msg})
	print(concat(msg, '&'), '\n')
    else
	print(msg, '\n')
    end

    if PRINT[cmd] then
	local uid, m = switch(cmd, msg, send)
	printer:send_msgs( m )
	print('UID:', uid)
    end

    if FEED[cmd] then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local conn = getConn(uid)
	local qry = format(QTKT, uid)
	fd.reduce(conn.query(qry), fd.map(mail(fruit, cmd)), deliver, msgr)
	print'OK feed!\n'
    end

    if TABS[cmd] then
	local ret = tabs( cmd, pid, msg )
	if type(ret) == 'table' then
	    fd.reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK tabs!\n'
    end

    if VERS[cmd] then
	local ret = vers( cmd, msg )
	if type(ret) == 'table' then
	    fd.reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK vers!\n'
    end

end


