#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local into		= require'carlos.sqlite'.into
local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local dbconn		= require'carlos.ferre'.dbconn
local connexec		= require'carlos.ferre'.connexec
local receive		= require'carlos.ferre'.receive
local decode		= require'carlos.ferre'.decode
local now		= require'carlos.ferre'.now
local newTable    	= require'carlos.sqlite'.newTable

local format	= require'string'.format
local concat 	= table.concat
local remove	= table.remove
local open	= io.open
local date	= os.date
local assert	= assert

local pairs	= pairs

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7
local QUERIES	 = 'ipc://queries.ipc'

local TABS	 = {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'clave', 'desc', 'costol', 'unidad', 'precio', 'qty', 'rea', 'totalCents'}
local PEOPLE	= {}

local QRY	= 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
local QUID	= 'SELECT uid, SUBSTR(uid, -1) nombre, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND((SUM(totalCents)+50)/100, 2) total, tag FROM tickets WHERE uid %s %q GROUP BY uid'
local QTKT	= 'SELECT * FROM tickets WHERE uid LIKE %q'


--------------------------------
-- Local function definitions --
--------------------------------
--
--[[
local function dumpPEOPLE(conn)
    local QRY = 'SELECT id, nombre FROM empleados'
    local FIN = open(DEST, 'w')

print'\nWriting people to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end
--]]

local function process(uid, tag, conn2)
    return function(q)
	local o = {uid=uid, tag=tag}
	for k,v in q:gmatch'([%a%d]+)|([^|]+)' do o[k] = v end
	local lbl = 'u' .. o.precio:match'%d$'
	local b = fd.first(conn2.query(format(QRY, o.clave)), function(x) return x end)
	fd.reduce(fd.keys(o), fd.merge, b)
	b.precio = b[o.precio]; b.unidad = b[lbl]
	return fd.reduce(INDEX, fd.map(function(k) return b[k] or '' end), fd.into, {})
    end
end

local function asweek(t) return date('Y%YW%U', t) end

local function addTicket(conn, conn2, msg)
    local tag, data, uid = msg:match'(%a+)%spid=%d+&([^!]+)&uid=([^!]+)$'
    fd.reduce(fd.wrap(data:gmatch'query=([^&]+)'), fd.map(process(uid, tag, conn2)), into'tickets', conn)
--    return 'Data received and stored!'
    return uid
end

local function getName(o) o.nombre = PEOPLE[o.nombre] or 'NaP'; return o end

local function dumpFEED(conn, fruit, qry)
    local ROOT = '/var/www/htdocs/app-ferre/caja/json'
    local FIN = open(format('%s/%s-feed.json', ROOT, fruit), 'w')
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(qry), fd.map(getName), fd.map(asJSON), fd.into, {}), ',\n') )
    FIN:write']'
    FIN:close()
    return 'Updates stored and dumped'
end
---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local PRECIOS = assert( dbconn'ferre' )

local WEEK = assert( dbconn( asweek(now()), true ) )

fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(WEEK, format(newTable, tbname, schema)) end)

print("ferre and this week DBs were successfully open\n")
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local queues = assert(CTX:socket'ROUTER')

assert(queues:bind( QUERIES ))

print('Successfully bound to:', QUERIES)
--
-- -- -- -- -- --
--
-- Store PEOPLE values
--
fd.reduce(PRECIOS.query'SELECT * FROM empleados', fd.rejig(function(o) return o.nombre, o.id end), fd.merge, PEOPLE)
--
-- -- -- -- -- --
-- Run loop
--
while true do
print'+\n'
    pollin{queues}
    print'message received!\n'
    local id, msg = receive( queues )
    msg = msg[1]
    local cmd = msg:match'%a+'
-- following replies are to be sent to WEEK 
--
-- In case of a very very long ticket one should
-- be able to receive a file as in 'feed'
    if cmd == 'ticket' or cmd == 'presupuesto' then
	local uid = addTicket(WEEK, PRECIOS, msg)
	local qry = format(QUID, 'LIKE', uid)
	local msg = asJSON(getName(fd.first(WEEK.query(qry), function(x) return x end)))
	queues:send_msgs{'WEEK', format('feed %s', msg)}
	print(msg, '\n')
    end
    if cmd == 'feed' then
	local fruit = msg:match'%s(%a+)' -- secs = %s(%d+)$
	local t = date('%FT%T', now()):sub(1, 10)
	local qry = format(QUID, '>', t)
	print(dumpFEED( WEEK, fruit, qry ), '\n')
	queues:send_msgs{'WEEK', format('%s feed %s-feed.json', fruit, fruit)}
    end
    if cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local qry   = format(QTKT, uid)
	print(dumpFEED( WEEK, fruit, qry ), '\n')
	queues:send_msgs{'WEEK', format('%s uid %s-feed.json', fruit, fruit)}
    end
end

--[[    
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'DB' then
	    queues:send_msgs{id, 'Bye DB'}
	    break
	end
    end
--]]

