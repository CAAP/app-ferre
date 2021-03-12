#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'
local rconnect	  = require'redis'.connect
local socket	  = require'lzmq'.socket
local pollin	  = require'lzmq'.pollin
local aspath	  = require'carlos.ferre'.aspath
local asweek	  = require'carlos.ferre'.asweek
local now	  = require'carlos.ferre'.now
local uid2week	  = require'carlos.ferre'.uid2week
local catchall	  = require'carlos.ferre'.catchall
local ticket	  = require'carlos.ticket'.ticket
local connect	  = require'carlos.sqlite'.connect
local into	  = require'carlos.sqlite'.into
local newTable    = require'carlos.sqlite'.newTable
local split	  = require'carlos.string'.split

local json	  = require'json'.encode
local fromJSON	  = require'json'.decode
local serialize	  = require'carlos.ferre'.serialize
local deserialize = require'carlos.ferre'.deserialize
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
local QIDS	  = 'queue:uuids'
local QUPS	  = 'queue:ups:'

local QLPR	  = 'SELECT * FROM lpr WHERE uid LIKE %q'
local QUID	  = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QTKT	  = 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local WKDB 	  = asweek(now())

local FERRE	  = connect':inmemory:'
local WEEK

local SCHEME	  = client:hget('sql:week', 'tickets')

local QUERIES	  = {tickets={'SELECT * FROM tickets WHERE uid > %q', 'INSERT INTO tickets SELECT * FROM week.tickets WHERE uid > %q', format(newTable, 'tickets', SCHEME), 'INSERT INTO tickets SELECT * FROM week.tickets', 'SELECT * FROM tickets'},
		     messages={'SELECT msg FROM updates WHERE vers > %q', 'INSERT INTO messages SELECT msg FROM week.updates WHERE vers > %q', 'CREATE TABLE messages (msg)', 'INSERT INTO messages SELECT msg FROM week.updates', 'SELECT * FROM messages'},
		     queries={'SELECT * FROM queries WHERE vers > %q', 'INSERT INTO queries SELECT * FROM week.queries WHERE vers > %q', format(newTable, 'queries', client:hget('sql:week', 'queries')), 'INSERT INTO queries SELECT * FROM week.queries', 'SELECT * FROM queries'}}

local INDEX 	  = fd.reduce(split(SCHEME, ',', true), fd.map(function(s) return s:match'%w+' end), fd.into, {})


--------------------------------
-- Local function definitions --
--------------------------------

local function fix(w)
    return function(o)
	o.fruit = w.fruit
	o.cmd = w.cmd
	return o
    end
end

local function byDesc(s)
    local qry = format('SELECT clave FROM datos WHERE desc LIKE %q ORDER BY desc LIMIT 1', s:gsub('*', '%%')..'%')
    local o = fd.first(FERRE.query(qry), function(x) return x end)
    return o
end

local function byClave(s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    local o = fd.first(FERRE.query(qry), function(x) return x end)
    return o
end

local function query(o)
    local fn = fix(o)
    if o.rfc then
	local QRY = format('SELECT * FROM clientes WHERE rfc LIKE "%s%%" LIMIT 4', o.rfc)
	local ans = fd.reduce(FERRE.query(QRY), fd.map(fn), fd.into, {})
	return ans

    elseif o.desc then
	local desc = o.desc
	if desc:match'VV' then return fn(byClave(byDesc(desc).clave))
	else return fn(byDesc(desc)) end

    elseif o.clave then return fn(byClave(o.clave)) end
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

local function update( clave )
    local k = QUPS..clave
    assert( client:exists(k), 'error: key cannot be nil' )
    local qs = client:lrange(k, 0, -1)
    -- QUERY --
    qs[#qs] = qs[#qs]:gsub('$QUERY', serialize(qs))
    --
    fd.reduce(qs, qryExec)
end

local function addTicket( uuid )
    assert(client:hexists('queue:tickets', uuid), 'error: uuid must exists')
    local data = deserialize( client:hget('queue:tickets', uuid) )
    if #data > 6 then
	fd.slice(5, data, into'tickets', WEEK)
    else
	fd.reduce(data, into'tickets', WEEK)
    end
    client:hdel('queue:tickets', uuid)
end

local function header(uid) return fd.first(WEEK.query(format(QUID, uid)), function(x) return x end) end

local function lpr(uid)
    local hdr = header(uid)
    local qry = format(QLPR, uid)
    local data = fd.reduce(WEEK.query(qry), fd.into, {})
    client:hset(QIDS, uid, serialize(ticket(hdr, data)))
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

    if week == WKDB then return {format(QS[1], vers)} end -- assert vers exists XXX

    local wks = {WKDB}
    local t = now() - 3600*24*7
    local w = asweek(t)
    while w > week do
	wks[#wks+1] = w
	t = t - 3600*24*7
	w = asweek(t)
    end
    wks[#wks+1] = week
    wks[#wks+1] = format(QS[2], vers) -- assert vers exists XXX

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
--[[
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
--]]
local function switch( cmd, o )
    local fruit, uid = o.fruit, o.uid

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
	local vers = o.version
	local week = uid2week(vers)
	local wks = weeks(week, vers)
	return gather(fruit, wks)

    end
end

local function setFruit(fruit, cmd)
    return function(o)
	o.fruit = fruit
	o.cmd = cmd
	return serialize(o)
    end
end


local function replyqry(skt, msg)
    local cmd, s = msg[1], msg[2]
    -- ambiguous, either object or array are valid, empty object is returned
    skt:send_msgs{'reroute', 'SSE', serialize(query(deserialize(s)))}
end

local function dolpr(skt, msg)
    local s = msg[2]
    lpr( deserialize(s).uid )
    skt:send_msgs{'reroute', 'lpr', s}
end

local function feed(skt, msg)
    local cmd, s = msg[1], msg[2]
    local fruit, conn, qry = switch(cmd, deserialize(s))
    local fn = setFruit(fruit, cmd)
    fd.reduce(conn.query(qry), function(o) skt:send_msgs{'reroute', 'SSE', fn(o)} end)
end

local function newup(_, msg)
    update( deserialize(msg[2]).clave )
end

local function newtkt(skt, msg)
    local s = msg[2]
    local w = deserialize( s )
    local uid = assert( w.uid )
    addTicket( w.uuid )
    local hdr = lpr( uid )
    hdr.cmd = 'feed'
    w.tag = hdr.tag
    skt:send_msgs{'reroute', 'SSE', serialize(hdr)}
    skt:send_msgs{'reroute', 'lpr', serialize(w)}
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
local tasks = assert(socket'DEALER')

assert( tasks:opt('immediate', true) )

assert( tasks:opt('linger', 0) )

assert( tasks:opt('id', 'inmem') )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--
-- -- -- -- -- --
--

local function deliver(skt) return function(o) skt:send_msgs{'reroute', 'SSE', serialize(o)} end end

local function donothing(skt, msg)
    local cmd, s = msg[1], msg[2]
    local w = deserialize(msg)
    local peer = w.peer

    local wks = weeks(uid, 'queries')
    local _, conn, qry = gather('queries', wks)
    fd.reduce(conn.query(qry), fd.map(function(o) o.peer = peer; return o; end), deliver, tasks)
end

local router = { query=replyqry, rfc=replyqry,
		 bixolon=dolpr,  update=newup, ticket=newtkt,
		 uid=feed, 	 feed=feed,    ledger=feed,   adjust=feed,
	 	 versionx=donothing}

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
    local vers = fd.first(WEEK.query'SELECT MAX(vers) vers FROM updates', function(x) return x end).vers or '0'
    if vers > '0' then
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

    local events = tasks:opt'events'

    if events.pollin then
	-- two messages received: cmd & [binser] Lua Object --
	local msg = tasks:recv_msgs()
	local cmd = msg[1]

	print(concat(msg, ' '), '\n')

	if cmd == 'OK' then
	else catchall(router, tasks, cmd, msg, {'reroute', 'SSE', ''}) end -- router[cmd](tasks, msg)

    end

end

--[[
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
--]]

