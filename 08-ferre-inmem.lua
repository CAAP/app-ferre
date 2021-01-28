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
local newTable    = require'carlos.sqlite'.newTable
local split	  = require'carlos.string'.split

local asJSON	  = require'json'.encode
local fromJSON	  = require'json'.decode
local dN 	  = require'binser'.deserializeN
local serialize	  = require'binser'.serialize
local fb64	  = require'lints'.fromB64
local b64	  = require'lints'.asB64
local posix	  = require'posix.signal'

local concat	  = table.concat
local unpack	  = table.unpack
local format	  = string.format
local tointeger   = math.tointeger
local type	  = type
local exit	  = os.exit
local pcall	  = pcall
local assert	  = assert
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'

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

local FEED	  = { uid=true, feed=true, ledger=true, adjust=true }
local WKDB 	  = asweek(now())

local FERRE	  = connect':inmemory:'
local WEEK

local SCHEME	  = client:hget('sql:week', 'tickets')

local QUERIES	  = {tickets={'SELECT * FROM tickets WHERE uid > %q', 'INSERT INTO tickets SELECT * FROM week.tickets WHERE uid > %q', format(newTable, 'tickets', SCHEME), 'INSERT INTO tickets SELECT * FROM week.tickets', 'SELECT * FROM tickets'},
		     messages={'SELECT msg FROM updates WHERE vers > %d', 'INSERT INTO messages SELECT msg FROM week.updates WHERE vers > %d', 'CREATE TABLE messages (msg)', 'INSERT INTO messages SELECT msg FROM week.updates', 'SELECT * FROM messages'},
		     queries={'SELECT * FROM queries WHERE vers > %d', 'INSERT INTO queries SELECT * FROM week.queries WHERE vers > %d', format(newTable, 'queries', client:hget('sql:week', 'queries')), 'INSERT INTO queries SELECT * FROM week.queries', 'SELECT * FROM queries'}}

local INDEX 	  = fd.reduce(split(SCHEME, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})


--------------------------------
-- Local function definitions --
--------------------------------
local function deliver( skt )
    return function(m, i)
	if type(m)  == 'table' then skt:send_msgs(m)
	else skt:send_msgs{'SSE', m} end
    end
end

local function prepare( a ) if a.msg then return a.msg else return asJSON(a) end end

local function mail(fruit, cmd)
    return function(a)
	if type(a) == 'table' then return {fruit, cmd, unpack(a)}
	else return format('%s %s %s', fruit, cmd, a) end
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
    -- QUERY -- XXX
    qs[#qs] = qs[#qs]:gsub('$QUERY', b64(serialize(qs)))
    --
    fd.reduce(qs, qryExec)
end

local function deserialize(s)
    local a,i = dN(fb64(s), 1)
    return a
end

local function addTicket( uid )
    local k = 'queue:tickets:'..uid
    local data = client:lrange(k, 0, -1)
    if #data > 6 then
	fd.slice(5, data, fd.map(deserialize), into'tickets', WEEK)
    else
	fd.reduce(data, fd.map(deserialize), into'tickets', WEEK)
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
	assert( conn.exec'CREATE TABLE queries AS SELECT * FROM week.queries' )
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

local function weeks(week, vers)
    local QS = QUERIES.messages

    if vers == 'tickets' then
	QS = QUERIES.tickets
	vers = week
	week = uid2week(week)
    elseif vers == 'queries' then
	QS = QUERIES.queries
	local w = fromJSON(week)
	week = w.week
	vers = w.vers
    end

    if week == WKDB then return {format(QS[1], vers)} end

    local wks = {WKDB}
    local t = now() - 3600*24*7
    local w = asweek(t)
    while w > week do
	wks[#wks+1] = w
	t = t - 3600*24*7
	w = asweek(t)
    end
    wks[#wks+1] = week
    wks[#wks+1] = format(QS[2], vers)

    return wks
end

local function addDATA(conn, wks, qry)
    local WW = #wks
    assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(wks[WW-1]))) )
    assert( conn.exec(wks[WW]) )
    assert( conn.exec'DETACH DATABASE week' )

    for i=#wks-2, 1, -1 do
	local wk = wks[i]
	assert( conn.exec(format('ATTACH DATABASE %q AS week', aspath(wk))) )
	assert( conn.exec(qry) )
	assert( conn.exec'DETACH DATABASE week' )
    end
end

local function gather(fruit, wks)
    local QS = QUERIES[fruit] or QUERIES.messages

    if #wks == 1 then
	return fruit, WEEK, wks[1]

    else
	local conn = connect':inmemory:'
	assert( conn.exec(QS[3]) )
	addDATA(conn, wks, QS[4])
	return fruit, conn, QS[5]
    end
end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function groupon(uid)
    local u = uid
    local tks = {}
    return function(step)
    return function(a,i)
	if not(tks.uid) then tks.uid = a.uid end
	local tuid = tks.uid
	if a.uid ~= tuid then
	    local ou = u
	    u = a.uid
	    local ID = 'queue:tickets:'..u
	    fd.reduce(tks, function(w) client:rpush(ID, b64(serialize(w))) end)
	    client:expire(ID, 10)
	    tks = {uid=u, a}
	    step({u, ou}, i)
	else
	    tks[#tks+1] = fd.reduce(a, fd.map(indexar), fd.into, {})
	end
    end
    end
end

local function chain(vers)
    local v = vers
    return function(step)
    return function(a, i)
	local ov = v
	v = a.version
	step({v, ov, a.clave, a.query}, i)
    end
    end
end

local function switch( cmd, msg )
    local fruit = msg:match'fruit=(%a+)' or msg
    local uid   = msg:match'uid=([^!&]+)'

    if cmd == 'uid' then
	local conn = getConn(uid)
	local qry = format(QTKT, uid)
	return fruit, conn, qry

    elseif cmd == 'feed' then
	local qry = format('SELECT * FROM uids WHERE uid > "%s"', TODAY)
	return fruit, WEEK, qry

    elseif cmd == 'ledger' then
	local conn = getConn(uid)
	local qry = format('SELECT * FROM uids WHERE uid LIKE "%s%%"', uid)
	return fruit, conn, qry

    elseif cmd == 'adjust' then
	local vers = tointeger(msg:match'vers=(%d+)')
	local fruit = msg:match'fruit=(%a+)'
	local week = msg:match'week=([%u%d]+)'
	local wks = weeks(week, vers)
	return gather(fruit, wks)

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

do
    local path = aspath'ferre'
    assert( FERRE.exec(format('ATTACH DATABASE %q AS ferre', path)) )
    assert( FERRE.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
    assert( FERRE.exec'DETACH DATABASE ferre' )
    print('items in datos:', FERRE.count'datos', '\n')

    WEEK = addDB( WKDB, true )
    print('items in tickets:', WEEK.count'tickets', '\n')

    -- VERS can be ZERO from now on
    local vers = fd.first(WEEK.query'SELECT MAX(vers) vers FROM updates', function(x) return x end).vers or 0
    if vers > 0 then
	vers = asJSON{week=WKDB, vers=vers}
	client:set('app:updates:version', vers)
    else vers = client:get('app:updates:version') end
    print('\nVersion:', vers, '\n')

    -- TICKETS
    fd.reduce(WEEK.query'SELECT SUBSTR(uid,-2) zip, MAX(uid) uid FROM tickets GROUP BY zip', function(w) client:set(format('app:tickets:FA-BJ-%.2d', w.zip), w.uid) end)
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
	    tasks:send_msgs{'lpr', uid}

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
	    tasks:send_msgs{'lpr', uid}
	    if hdr.tag == 'facturar' then tasks:send_msgs{'lpr', uid} end

	-- peer --
	elseif cmd == 'queryx' then
	    local DST, uid = msg[2], msg[3]
	    if uid:match'%d+%-%d+%-%d+T' then 	-- ticket
		local wks = weeks(uid, 'tickets')
		local _, conn, qry = gather('tickets', wks)
		fd.reduce(conn.query(qry), groupon(uid), fd.map(mail('peer', DST)), deliver, tasks)

	    else  -- vers
		local wks = weeks(uid, 'queries')
		local _, conn, qry = gather('queries', wks)
		fd.reduce(conn.query(qry), chain(uid), fd.map(mail('peer', DST)), deliver, tasks)

	    end
	end
    end
end

