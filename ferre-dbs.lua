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
local newTable    	= require'carlos.sqlite'.newTable
local dump		= require'carlos.files'.dump

local format	= require'string'.format
local concat 	= table.concat
local remove	= table.remove
local open	= io.open
local time	= os.time
local date	= os.date
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7
local QUERIES	 = 'ipc://queries.ipc'
local DEST_PRIC	= '/var/www/htdocs/app-ferre/ventas/json/precios.json'
local DEST_VERS	= '/var/www/htdocs/app-ferre/ventas/json/version.json'
local DEST_PEOP	= '/var/www/htdocs/app-ferre/ventas/json/people.json'

local PEERS	 = {}
local SUBS	 = {'ticket', 'presupuesto', 'version', 'KILL'} -- CACHE
local VERS	 = {} -- week, vers
local TABS	 = {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'clave', 'desc', 'costol', 'unidad', 'precio', 'qty', 'rea', 'totalCents'}

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
    while vers == 0 do -- change in YEAR XXX
	hoy = hoy - SEMANA
	week = asweek( hoy )
	vers = which( week )
--	if week:match'W00' then break end
    end
    w.week = week; w.vers = vers
    return w
end

-- remove 'vers' since it's an extra event in itself and add arg 'store'
local function prepare(w)
    w.vers = nil
    w.store = 'PRECIOS'
    return w
end

local function asDATA(w) return format('event: update\ndata: %s\n', asJSON(w)) end

local function fromWeek(week, vers)
    local conn =  dbconn(week)
    local clause = format('WHERE vers > %d', vers)
    local N = conn.count('updates', clause)

    if N > 0 then
	local data = fd.reduce(conn.query(format(UP_QUERY, clause)), fd.map(prepare), fd.map(asDATA), fd.into, {})
	data[#data+1] = format('event: update\ndata: %s\n\n', asJSON{vers=N, week=week, store='VERS'})
	return concat(data, '\n')
    else
	return ':empty\n\n'
    end
end

local function myVersion() return format('version %s', asJSON(VERS)) end

local function dumpVERS() dump(DEST_VERS, asJSON(VERS)) end

local function nulls(w)
    if w.precio2 == 0 then w.precio2 = nil end
    if w.precio3 == 0 then w.precio3 = nil end
    return w
end

local function dumpPRICE(conn)
    local QRY = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'
    local FIN = open(DEST, 'w')

print'\nWriting data to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(nulls), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end

local function dumpPEOPLE(conn)
    local QRY = 'SELECT id, nombre FROM empleados'
    local FIN = open(DEST, 'w')

print'\nWriting people to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end

-- ITERATIVE procedure AWESOME
local function nextWeek(t) return {t=t+SEMANA, vers=0} end

local function backintime(week, t) while week < asweek(t) do t = t - 3600*24*7 end; return t end

local function stream(week, vers)
    local function iter(WEEK, o)
	local w = asweek( o.t )
	if w > WEEK then return nil
	else return nextWeek(o.t), fromWeek(week, o.vers) end
    end
    return function() return iter, VERS.week, {t=backintime(week, now()), vers=vers} end
end

local function adjust(msgr, id, msg)
    local fruit, week, vers = msg:match'(%a+)%s(%a+)%s(%a+)$'
    fd.reduce(stream(week, vers), function(s) msgr:send_msgs{id, format('%s update %s', fruit, s)} end)
    return 'Updates sent'
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
-- -- -- -- -- --
--
-- Compute latest version
--
version(VERS) -- latest version for UPDATES

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers, '\n') -- print latest version
-- -- -- -- -- --
--
-- Dump data to files
--
dumpVERS(); dumpPRICE( PRECIOS ); dumpPEOPLE( PRECIOS )
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
    if cmd == 'Hi' then
	local peer = msg:match'%a+$'
	PEERS[peer] = id
	tasks:send_msgs{id, myVersion()}
    end
    if cmd == 'adjust' then print( adjust(tasks, id, msg), '\n' ) end
    if cmd == 'version' then tasks:send_msgs{id, myVersion()} end
    if cmd == 'ticket' or cmd == 'presupuesto' then
	d
    end
end

