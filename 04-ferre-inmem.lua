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
local aspath		= require'carlos.ferre'.aspath
local uid2week		= require'carlos.ferre'.uid2week

local concat 	= table.concat
local remove	= table.remove
local assert	= assert
local type	= type
local format	= string.format
local tointeger = math.tointeger
local env	= os.getenv
local print	= print

local WEEK 	= asweek( os.time() ) -- now

local TODAY	= os.date('%F', os.time()) -- now

local HR	= os.time()

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM	 = env'STREAM_IPC'
local BIXOLON	 = 'ipc://bixolon.ipc'

local TABS	 = { tabs=true, delete=true, msgs=true,
		     pins=true, login=true, CACHE=true }
local VERS	 = { version=true, update=true, CACHE=true }
local FEED	 = { uid=true, feed=true, ledger=true } -- adjust
local PRINT	 = { ticket=true, bixolon=true }

local DIRTY	 = {clave=true, tbname=true, fruit=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}

local QUID	 = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QLPR	 = 'SELECT * FROM lpr WHERE uid LIKE %q'
local QTKT	 = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local SUID	 = 'CREATE VIEW uids AS SELECT uid, SUBSTR(uid, 12, 5) time, COUNT(uid) count, ROUND(SUM(totalCents)/100.0, 2) total, tag, nombre FROM tickets WHERE tag NOT LIKE "factura" GROUP BY uid'
local SLPR	 = 'CREATE VIEW lpr AS SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal, uid FROM tickets'
local SALES	 = 'CREATE VIEW sales AS SELECT SUBSTR(uid,1,10) day, SUBSTR(uid,12,5) hour, ((SUBSTR(uid,12,2)-9)*60 + SUBSTR(uid, 15, 2))/10 mins, uid, nombre, totalCents, qty FROM tickets'

local INDEX
local DB	= {}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function receive(skt, a)
    return fd.reduce(function() return skt:msgs(true) end, fd.into, a)
end

local function deliver( skt ) return function(m, i) skt:send_msg( m ) end end

local function mail(fruit, cmd)
    return function(a)
	return format('%s %s %s', fruit, cmd, asJSON(a))
    end
end

local function mymsg(fruit, cmd)
    return function(a)
	return format('%s %s %s', fruit, cmd, a.msg)
    end
end

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat2(clave, n)
    clave = tointeger(clave) or format('%q', clave) -- "'%s'"
    return function(v, k)
	n = n + 1
	local vv = smart(v, k)
	local ret = {n, clave, k, vv}
	return ret
    end
end

local function weeks(w)
    local t = HR
    local wks = {WEEK}
    while w < wks[#wks] do t = t - 3600*24*7; wks[#wks+1] = asweek(t) end
    remove(wks) -- itself
    return wks
end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function addDB(week, ups)
    local conn = connect':inmemory:'
    DB[week] = conn
    assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(week))) )
    assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
    if ups then
	assert( conn.exec'CREATE TABLE updates AS SELECT * FROM week.updates' )
    end
    assert( conn.exec'DETACH DATABASE week' )
    assert( conn.exec(SUID) )
    assert( conn.exec(SLPR) )
    assert( conn.exec(SALES) )
    return conn
end

local function tryDB(conn, week, vers)
    local k = vers > 0 and 'WHERE vers > '.. vers or ''
    local qry = format('INSERT INTO messages SELECT msg FROM week.updates %s', k)
    assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(week))) )
    assert( conn.exec(qry) )
    assert( conn.exec'DETACH DATABASE week' )
end

local function getConn(uid)
    local week = uid2week(uid)
    return DB[week] or addDB(week, false)
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

local function switch(cmd, msg, tasks)
    if cmd == 'ticket' then
	remove(msg, 1)
	local uid, conn = addAll(msg)
	local m = header(uid, conn)
	tasks:send_msgs{'SSE', 'feed', asJSON(m)}
	return uid, ticket(m, bixolon(uid, conn))
    elseif cmd == 'bixolon' then
	local uid = msg[2]:match'uid=([^!]+)'
	local conn = getConn(uid)
	local m = header(uid, conn)
	return uid, ticket(m, bixolon(uid, conn))
    end
end

local function commute(cmd, msg)
	msg = msg[2]
    if cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local conn = getConn(uid)
	local qry = format(QTKT, uid)
	return fruit, conn, qry
    elseif cmd == 'feed' then
	local fruit = msg
	local conn = DB[WEEK]
	local qry = format('SELECT * FROM uids WHERE uid > "%s%%"', TODAY)
	return fruit, conn, qry
    elseif cmd == 'ledger' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local conn = getConn(uid)
	local qry = format('SELECT * FROM uids WHERE uid LIKE "%s%%"', uid)
	return fruit, conn, qry
    end

end
---------------------------------
-- Program execution statement --
---------------------------------
--
-- -- -- -- -- --
--

do
    local conn = addDB( WEEK, true )
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

local function send( m ) tasks:send_msgs{'SSE', m} end

--
--
-- Run loop
--

while true do
print'+\n'

    pollin{tasks}

    local msg = tasks:recv_msgs(true)
    local cmd = msg[1]:match'%a+'

    print(concat(msg, ' '), '\n')

    if PRINT[cmd] then
	local uid, m = switch(cmd, msg, tasks)
	printer:send_msgs( m )
	print('UID:', uid)
    end

    if FEED[cmd] then
	local fruit, conn, qry = commute(cmd, msg)
--XXX	fd.reduce(conn.query(qry), fd.map(mail(fruit, cmd)), deliver, msgr)
	print'OK feed!\n'
    end

    if TABS[cmd] then
	local ret = tabs( msg )
	if type(ret) == 'table' then
	    fd.reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK tabs!\n'
    end

    if cmd == 'update' then
	local conn = DB[WEEK]
	assert(conn.exec( msg[2] ))
	msg = msg[#msg] -- vers as json
    end

    if VERS[cmd] then
	local ret = vers( msg )
	if type(ret) == 'table' then
	    fd.reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK vers!\n'
    end

    if cmd == 'adjust' then
	
	local vers = tointeger(msg:match'vers=(%d+)')
	local fruit = msg:match'fruit=(%a+)'
	local week = msg:match'week=([^!&]+)'
	-- week is NOT this WEEK
	if week < WEEK then
	    local conn = connect':inmemory:'
	    assert( conn.exec'CREATE TABLE messages (msg)' )
	    local wks = weeks(week)
	    while week < WEEK do
		tryDB( conn, week, vers )
		week = remove(wks)
		vers = 0
	    end
--XXX	    fd.reduce(conn.query'SELECT * FROM messages', fd.map(mymsg(fruit, cmd)), deliver, msgr)
	end
	-- week IS this WEEK
	local conn = DB[WEEK]
	local qry = format('SELECT msg FROM updates where vers > %d', vers)
-- XXX	fd.reduce(conn.query(qry), fd.map(mymsg(fruit, cmd)), deliver, msgr)
    end

end
