#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'
local rconnect	  = require'redis'.connect
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local aspath	  = require'carlos.ferre'.aspath
local asweek	  = require'carlos.ferre'.asweek
local now	  = require'carlos.ferre'.now
local uid2week	  = require'carlos.ferre'.uid2week
local ticket	  = require'carlos.ticket'.ticket
local connect	  = require'carlos.sqlite'.connect
local into	  = require'carlos.sqlite'.into

local asJSON	  = require'json'.encode
local deserializeN = require'binser'.deserializeN
local posix	  = require'posix.signal'

local concat	  = table.concat
local unpack	  = table.unpack
local format	  = string.format
local tointeger   = math.tointeger
local exit	  = os.exit
local pcall	  = pcall
local assert	  = assert
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'
local BIXOLON	  = os.getenv'LPR_IPC'

local TODAY	  = os.date('%F', os.time()) -- now

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	  = assert( rconnect('127.0.0.1', '6379') )
local WSQL 	  = 'sql:week'
local QIDS	  = 'queue:uuids:'

local QLPR	  = 'SELECT * FROM lpr WHERE uid LIKE %q'
local QUID	  = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QTKT	  = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local FEED	 = { uid=true, feed=true, ledger=true, adjust=true }
local WKDB 	 = asweek(now())

local FERRE	  = connect':inmemory:'
local WEEK

--------------------------------
-- Local function definitions --
--------------------------------
local function deliver( skt ) return function(m, i) skt:send_msgs{'SSE', m} end end

local function prepare( a ) if a.msg then return a.msg else return asJSON(a) end end

local function mail(fruit, cmd)
    return function(a)
	return format('%s %s %s', fruit, cmd, a)
    end
end

local function byDesc(s)
    local qry = format('SELECT clave FROM datos WHERE desc LIKE %q ORDER BY desc LIMIT 1', s:gsub('*', '%%')..'%')
    local o = fd.first(FERRE.query(qry), function(x) return x end)
    return (o and o.clave or '')
end

local function byClave(s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    local o = fd.first(FERRE.query(qry), function(x) return x end)
    return o and asJSON( o ) or ''
end

local function queryDB(msg)
    if msg:match'desc' then
	local ret = msg:match'desc=([^!&]+)'
	if ret:match'VV' then
	    return byClave(byDesc(ret))
	else
	    return byDesc(ret)
	end

    elseif msg:match'clave' then
	local ret = msg:match'clave=([%a%d]+)'
	return byClave(ret)

    end
end

local function queryRFC(rfc)
    local QRY = format('SELECT * FROM clientes WHERE rfc LIKE "%s%%" LIMIT 4', rfc)
    local ans = fd.reduce(FERRE.query(QRY), fd.into, {})
    return #ans > 0 and asJSON(ans) or '[]'
end

local function execUP( f )
    local e,s = pcall(f)
    return (not(e) and s or '')
end

local function qryExec(q)
    local s
    if q:match'datos' then
	s = execUP(function() return FERRE.exec(q) end)
    else
	s = execUP(function() return WEEK.exec(q) end)
    end
    print(q, s, '\n')
end

local function update( uid )
    local k = QIDS..uid
    local qs = client:lrange(k, 0, -1)
    fd.reduce(qs, qryExec)
end

local function deserialize(w)
    local a,i = deserializeN(w, 1)
    return a
end

local function addTicket( uid )
    local k = 'queue:tickets:'..uid
    local qs = client:lrange(k, 0, -1)
    if #qs > 6 then
	fd.slice(5, qs, fd.map(deserialize), into'tickets', WEEK)
    else
	fd.reduce(qs, fd.map(deserialize), into'tickets', WEEK)
    end
    return uid
end

local function header(uid) return fd.first(WEEK.query(format(QUID, uid)), function(x) return x end) end

local function lpr(uid)
    assert(uid, 'ERROR: uid cannot be nil')
    local hdr = header(uid)
    local qry = format(QLPR, uid)
    local data = fd.reduce(WEEK.query(qry), fd.into, {})
    local k = QIDS..uid
    client:rpush(k, unpack(ticket(hdr, data)))
    client:expire(k, 120)
    return hdr
end

local function addDB(week, ups)
    local conn = connect':inmemory:'
    assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(week))) )
    assert( conn.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
    if ups then
	assert( conn.exec'CREATE TABLE updates AS SELECT * FROM week.updates' )
    end
    assert( conn.exec'DETACH DATABASE week' )

    conn.exec( client:hget(WSQL, 'uids') ) -- temp views
    conn.exec( client:hget(WSQL, 'sales') ) -- temp views
    conn.exec( client:hget(WSQL, 'lpr') ) -- temp views
    print(week, "DB was successfully open\n")

    return conn
end

local function getConn(uid)
    local week = uid2week(uid)
    if week == WKDB then return WEEK
    else return addDB(week, false) end
end

local function switch( cmd, msg )
    local fruit = msg:match'fruit=(%a+)' or msg
    local uid   = msg:match'uid=([^!&]+)'

    if cmd == 'uid' then
	local conn = getConn(uid)
	local qry = format(QTKT, uid)
	return fruit, conn, qry

    elseif cmd == 'feed' then
	local qry = format('SELECT * FROM uids WHERE uid > "%s%%"', TODAY)
	return fruit, WEEK, qry

    elseif cmd == 'ledger' then
	local conn = getConn(uid)
	local qry = format('SELECT * FROM uids WHERE uid LIKE "%s%%"', uid)
	return fruit, conn, qry

    elseif cmd == 'adjust' then
	local vers = tointeger(msg:match'vers=(%d+)')
	local fruit = msg:match'fruit=(%a+)'
	local week = msg:match'week=([^!&]+)'
	-- week is NOT this WEEK
	if week < WKDB then
	    local conn = connect':inmemory:'
	    assert( conn.exec'CREATE TABLE messages (msg)' )
	    local wks = weeks(week) -- XXX not defined yet
	    while week < WKDB do
		tryDB( conn, week, vers )
		week = remove(wks)
		vers = 0
	    end
	    return fruit, conn, 'SELECT * FROM messages'
	else
	    return fruit, WEEK, format('SELECT msg FROM updates where vers > %d', vers)
	end
	
    end
end

---------------------------------
-- Program execution statement --
---------------------------------

local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
-- Initilize server(s)
--
local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:linger(0) )

assert( tasks:set_id'inmem' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--
-- -- -- -- -- --
--
local printer = assert(CTX:socket'PUSH')

assert( printer:immediate( true ) )

assert( tasks:linger(0) )

assert( printer:connect( BIXOLON ) )

print('\nSuccessfully connected to:', BIXOLON)

--
-- -- -- -- -- --
--
do
    local path = aspath'ferre'
    assert( FERRE.exec(format('ATTACH DATABASE %q AS ferre', path)) )
    assert( FERRE.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
    assert( FERRE.exec'DETACH DATABASE ferre' )
    print('items in datos:', FERRE.count'datos', '\n')

--[[
    path = aspath'personas'
    FERRE.exec(format('ATTACH DATABASE %q AS people', path))
    fd.reduce(FERRE.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, PID)
    FERRE.exec'CREATE TABLE clientes AS SELECT * FROM people.clientes'
    FERRE.exec'DETACH DATABASE people'
--]]

    WEEK = addDB( WKDB, true )
    print('items in tickets:', WEEK.count'tickets', '\n')

    -- VERS can be ZERO from now on
    local vers = fd.first(WEEK.query'SELECT MAX(vers) vers FROM updates', function(x) return x end).vers or 0
    vers = {week=WKDB, vers=vers}
    client:set( 'app:updates:version', asJSON(vers) )
    print('\nVersion:', asJSON(vers), '\n') -- tasks:send_msgs{'SSE', format('version %s', asJSON(vers))}
end

--
-- -- -- -- -- --
--

while true do
    print'+\n'

    pollin{tasks}

    if tasks:events() == 'POLLIN' then
	local msg = tasks:recv_msgs(true)
	local cmd = msg[1]

	print(concat(msg, ' '), '\n')

	if cmd == 'query' then
	    local fruit = msg[2]:match'fruit=(%a+)'
	    tasks:send_msgs{'SSE', fruit, 'query', queryDB(msg[2])}

	elseif cmd == 'rfc' then
	    msg = msg[2]
	    local fruit = msg:match'fruit=(%a+)'
	    local rfc = msg:match'rfc=(%a+)'
	    tasks:send_msgs{'SSE', fruit, 'rfc', queryRFC(rfc)}

	elseif cmd == 'bixolon' then
	    local uid = msg[2]:match'uid=([^!]+)'
	    lpr( uid )
--	    printer:send_msg( uid ) XXX

	elseif FEED[cmd] then
	    local fruit, conn, qry = switch(cmd, msg[2])
	    fd.reduce(conn.query(qry), fd.map(prepare), fd.map(mail(fruit, cmd)), deliver, tasks)
	    print'OK feed!\n'

	    -- preprocessed FROM db --

	elseif cmd == 'update' then
	    update(msg[2])

	elseif cmd == 'ticket' then
	    local uid = addTicket(msg[2])
	    local hdr = lpr( uid )
	    tasks:send_msgs{'SSE', 'feed', asJSON(hdr)}
--		printer:send_msg( uid ) XXX

	end
    end
end
