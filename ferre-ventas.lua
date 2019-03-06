#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local context	= require'lzmq'.context
local dbconn	= require'carlos.ferre'.dbconn
local connexec  = require'carlos.ferre'.connexec
local cache	= require'carlos.ferre'.cache
local urldecode	= require'carlos.ferre'.urldecode

local sql 	  = require'carlos.sqlite'

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local CACHE	 = cache'Hi VENTAS'
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local SUBS	 = {'ticket', 'presupuesto', 'CACHE', 'KILL'}
local VERS      = {} -- week, vers
local TABS	= {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'clave', 'desc', 'costol', 'unidad', 'precio', 'qty', 'rea', 'totalCents'}

	    const VARS = ['id', 'clave', 'qty', 'rea', 'precio', 'totalCents'];

	    desc, costol, unidad

--------------------------------
-- Local function definitions --
--------------------------------
--
local function now() return time()-21600 end

local function asweek(t) return date('Y%YW%U', t) end

-- if db file exists and 'updates' tb exists then returns count
local function which( db )
    local conn = dbconn( db )
    if conn and conn.exists'updates' then
	return conn.count'updates'
    else return 0 end
end

local function version(w)
    local hoy = now()
    local week = asweek( hoy )
    local vers = which( week )
    local semana = 3600 * 24 * 7
    while vers == 0 do -- change in YEAR XXX
	hoy = hoy - semana
	week = asweek( hoy )
	vers = which( week )
--	if week:match'W00' then break end
    end
    w.week = week; w.vers = vers
    return w
end

local function astab(s)
    local t = []
    for k,v in s:gmatch'([^|]+)|([^|]+)' do t[INDEX[k]] = v end
    return t
end

local function backup(msg)
    local pid = msg:match'pid=(%d+)'
    local iter = msg:gmatch'query=([^&]+)'
    fd.reduce(fd.wrap(iter), fd.map(urldecode), fd.map(), fd.into, {})
end
---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection
--
local conn = assert( dbconn( asweek(now()), true ) )

assert( conn.exec'ATTACH DATABASE "ferre.db" AS FERRE' ) -- to read: desc, ...

fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(format(sql.newTable, tbname, schema)) end)

print("This week's DB was successfully open\n")
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

fd.reduce(SUBS, function(s) assert(tasks:subscribe(s))  end)

print('Successfully connected to:', DOWNSTREAM)
print('And successfully subscribed to:', concat(SUBS, '\t'), '\n')
-- -- -- -- -- --
--
-- Connect to PUBlisher
local msgr = assert(CTX:socket'PUSH')

assert(msgr:connect( UPSTREAM ))

print('Successfully connected to:', UPSTREAM, '\n')
-- -- -- -- -- --
--
-- Compute latest version
--
version(VERS) -- latest version for UPDATES

CACHE.vers = 'version '..asJSON(VERS)

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers, '\n') -- print latest version
--updateVERS(VERS) -- write to hard-disk latest version for UPDATES
--
-- Run loop
--
while true do
print'+\n'
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'VENTAS' then
	    msgr:send_msg('Bye VENTAS')
	    break
	end
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
	goto FIN
    end
    -- presupuesto | ticket
    backup( msg )
--
    local pid = msg:match'pid=(%d+)'
    if cmd == 'presupuesto' then cache.delete( pid )
    elseif cmd == 'ticket' then cache.store(pid, msg) end
--
    msgr:send_msg( msg )
    print(msg, '\n')
    ::FIN::
end

