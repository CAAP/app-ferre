#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

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

local function asweek(t) return date('Y%YW%U', t) end

local function addTicket(conn, msg)
    local tag, data = msg:match'(%a+)%s([^!]+)'
    -- there're many 'query' elements to split
    local uid =  ---XXX
    fd.reduce(fd.wrap(data:gmatch'query=([^!])'), fd.map(decode), filterSOMEhow, sql.into'tickets', conn)
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
	addTicket(WEEK, msg)
    end
end

