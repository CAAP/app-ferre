#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local context	= require'lzmq'.context
local dbconn	= require'carlos.ferre'.dbconn
local connexec  = require'carlos.ferre'.connexec
local decode	= require'carlos.ferre'.decode

local sql 	  = require'carlos.sqlite'

local format	= require'string'.format
local concat 	= table.concat
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local CACHE	 = {}
local UPSTREAM	 = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local SUBS	 = {'ticket', 'presupuesto', 'CACHE', 'KILL'}
local VERS      = {} -- week, vers
local TABS	= {tickets = 'uid, tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}


--------------------------------
-- Local function definitions --
--------------------------------
--
local function store(pid, msg) CACHE[pid] = msg end

local function delete( pid ) CACHE[pid] = nil end

local function tofruit( fruit, m ) return format('%s %s', fruit, m) end

--local function sndkch(msgr, fruit) fd.reduce(fd.keys(CACHE), function(m) msgr:send_msg(tofruit(fruit, m)) end) end

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

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection
--
local conn = assert( dbconn( asweek(now()), true ) )

-- XXX attach ferre.db to read 'desc'

fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(format(sql.newTable, tbname, schema)) end)

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

msgr:send_msg('Hi TABS')
--
-- Compute latest version
--
version(VERS) -- latest version for UPDATES

msgr:send_msg('version '..asJSON(VERS))

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers, '\n') -- print latest version
--updateVERS(VERS) -- write to hard-disk latest version for UPDATES
--
-- Run loop
--


