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

local PEERS	 = {}
local SUBS	 = {'ticket', 'presupuesto', 'version', 'KILL'} -- CACHE
local TABS	 = {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'clave', 'desc', 'costol', 'unidad', 'precio', 'qty', 'rea', 'totalCents'}

local QRY	= 'SELECT * FROM precios WHERE clave LIKE %q LIMIT 1'
--------------------------------
-- Local function definitions --
--------------------------------
--
local function dumpPEOPLE(conn)
    local QRY = 'SELECT id, nombre FROM empleados'
    local FIN = open(DEST, 'w')

print'\nWriting people to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end

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
    return 'Data received and stored!'
end

local function dumpFEED(fruit, qry)
    local ROOT = '/var/www/htdocs/app-ferre/ventas/json'
    local FIN = open(format('%s/%s-feed.json', ROOT, fruit), 'w')
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(qry), fd.map(asJSON), fd.into, {}), ',\n') )
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

local tasks = assert(CTX:socket'ROUTER')

assert(tasks:bind( QUERIES ))

print('Successfully bound to:', QUERIES)
--
-- -- -- -- -- --
-- Run loop
--
while true do
print'+\n'
    pollin{tasks}
    print'message received!\n'
    local id, msg = receive( tasks )
    msg = msg[1]
    local cmd = msg:match'%a+'
    if cmd == 'ticket' or cmd == 'presupuesto' then
	print(addTicket(WEEK, PRECIOS, msg), '\n')
    end
    if cmd == 'feed' then
	local fruit, secs = msg:match'%s(%a+)%s(%d+)$'
	local t = date('%FT%T', now()-secs)
	local qry = format('SELECT * FROM tickets WHERE uid > %q', t)
	print(dumpFEED( fruit, qry ), '\n')
	tasks:send_msg(format('%s feed %s-feed.json', fruit, fruit))
    end
end

