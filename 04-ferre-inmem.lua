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

local concat 	= table.concat
local remove	= table.remove
local assert	= assert
local type	= type
local format	= string.format
local print	= print

local TICKETS	= connect':inmemory:'

local WEEK 	= asweek( now() )
local TODAY

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
local FEED	 = { feed=true, ledger=true, ticket=true } -- CACHE

local SUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag, nombre FROM tickets WHERE tag NOT LIKE "factura" GROUP BY uid'
local SLPR	 = 'SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal, uid FROM tickets'

local QUID	 = 'SELECT * FROM uids WHERE uid LIKE %q LIMIT 1'
local QLPR	 = 'SELECT * FROM lpr WHERE uid LIKE %q'

local INDEX

--------------------------------
-- Local function definitions --
--------------------------------
--

local function receive(skt, a)
    return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a)
end

local function some()
    local qry = format(QUID, '>', TODAY)
end

local function indexar(a) return fd.reduce(INDEX, fd.map(function(k) return a[k] or '' end), fd.into, {}) end

local function bixolon(uid)
    local qry = format(QLPR, uid)
    return fd.reduce(TICKETS.query(qry), fd.into, {})
end

local function addAll(msg)
    if #msg > 6 then
	fd.slice(5, msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', TICKETS)
    else
	fd.reduce(msg, fd.map(function(s) return fromJSON(s) end), fd.map(indexar), into'tickets', TICKETS)
    end
    return fromJSON(msg[1]).uid
end

local function switch(cmd, msg)
    if cmd == 'ticket' then
	remove(msg, 1)
	local uid = addAll(msg)
	local qry = format(QUID, uid)
	local m =  fd.first(TICKETS.query(qry), function(x) return x end)
	return uid, m
    end
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- -- -- -- -- --
--

do
    assert( TICKETS.exec(format('ATTACH DATABASE %q AS week', aspath(WEEK))) )
    assert( TICKETS.exec'CREATE TABLE tickets AS SELECT * FROM week.tickets' )
    assert( TICKETS.exec'DETACH DATABASE week' )
    assert( TICKETS.exec(format('CREATE VIEW uids AS %s', SUID)) )
    assert( TICKETS.exec(format('CREATE VIEW lpr AS %s', SLPR)) )

    INDEX = TICKETS.header'tickets'

print('items in tickets:', TICKETS.count'tickets', '\n')
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

    if FEED[cmd] then
	local uid, m = switch(cmd, msg)
	send( format('feed %s', asJSON(m)) )
	printer:send_msgs( ticket(m, bixolon(uid)) )
	print('UID:', uid)
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


