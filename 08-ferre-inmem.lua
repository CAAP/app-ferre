#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'
local rconnect	  = require'redis'.connect
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin
local split	  = require'carlos.string'.split
local aspath	  = require'carlos.ferre'.aspath
local asweek	  = require'carlos.ferre'.asweek
local now	  = require'carlos.ferre'.now
local connect	  = require'carlos.sqlite'.connect

local asJSON	  = require'json'.encode

local concat	  = table.concat
local format	  = string.format
local assert	  = assert
local print	  = print

local STREAM	  = os.getenv'STREAM_IPC'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local client	  = assert( rconnect('127.0.0.1', '6379') )
local WSQL 	  = 'sql:week'

local FERRE	  = connect':inmemory:'
local WEEK

--------------------------------
-- Local function definitions --
--------------------------------

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

---------------------------------
-- Program execution statement --
---------------------------------

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

--[[
    path = aspath'personas'
    FERRE.exec(format('ATTACH DATABASE %q AS people', path))
    fd.reduce(FERRE.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, PID)
    FERRE.exec'CREATE TABLE clientes AS SELECT * FROM people.clientes'
    FERRE.exec'DETACH DATABASE people'
--]]

    local WKDB = asweek(now())
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

	end
    end
end

