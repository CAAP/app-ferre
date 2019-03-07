#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local dbconn		= require'carlos.ferre'.dbconn
local connexec		= require'carlos.ferre'.connexec
local newTable    	= require'carlos.sqlite'.newTable

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7

local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'

local SUBS	 = {'ticket', 'presupuesto', 'CACHE', 'KILL'}
local VERS	 = {} -- week, vers
local TABS	 = {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}
local INDEX	= {'uid', 'tag', 'clave', 'desc', 'costol', 'unidad', 'precio', 'qty', 'rea', 'totalCents'}

	    const VARS = ['id', 'clave', 'qty', 'rea', 'precio', 'totalCents'];

	    desc, costol, unidad

local UP_QUERY = 'SELECT * FROM updates %s'

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

local function fromWeek(vers, week)
    local conn =  dbconn(week)
    local clause = format('WHERE vers > %d', vers)

    if conn.count('updates', clause) > 0 then
	return fd.reduce(conn.query(format(UP_QUERY, clause)), fd.map(asJSON), fd.into, {})
    else
	return ':empty'
    end
end

local function nextWeek(w) return {week=w.week + SEMANA, vers=0} end

-- MUST be ITERATIVE
local function adjust(conn, w)
    local WEEK = VERS.week

    local function iter(w, i)
	local week = w.week
	local vers = w.vers
	if week <= WEEK then
	    return i+1, nextWeek(w), fromWeek(vers, week)
	end
	return nil
    end

    return iter, w, 0
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection
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
--updatePRECIOS()  -- write to hard-disk latest version for PRECIOS - ferre.db
--
-- Run loop
--

