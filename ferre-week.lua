#! /usr/bin/env lua53

-- Import Section
local fd	= require'carlos.fold'
local sql	= require'carlos.sqlite'

local asJSON	= require'carlos.json'.asJSON
local dbconn	= require'carlos.ferre'.dbconn
local connexec	= require'carlos.ferre'.connexec
local dump	¡= require'carlos.files'.dump
local socket	= require'carlos.zmq'.socket
local poll	= require'lzmq'.pollin
local context	= require'lzmq'.context

local format	= require'string'.format
local assert	= assert
local time	= os.time
local date	= os.date
local env	= os.getenv

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPSTREAM   = 'ipc://upstream.ipc'
local DOWNSTREAM = 'ipc://downstream.ipc'
local ROOT	 = env'HOME' .. '/db/%s.db'
local DEST	 = '/var/www/htdocs/app-ferre/ventas/json/version.json'
local TIMEOUT	 = 2000 -- 2 secs
local VERS	 = {} -- week, vers
local TABS	 = {tickets = 'uid, id_tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}

--[[
    local keys = { uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7 }
    local clause = string.format("WHERE uid LIKE '%s%%'", today)
    local query = "SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE '%s%%' GROUP BY uid||id_tag" -- id_tag CHANGES
    local QRY = string.format('SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q %s GROUP BY uid', tbname, clause)
--]]

--------------------------------
-- Local function definitions --
--------------------------------

-- if db file exists and 'updates' tb exists then returns count
local function which( db )
    local conn = dbconn( db )
    if conn and conn.exists'updates' then
	return conn.count'updates'
    else return 0 end
end

local function now() return time()-21600 end

local function asweek(t) return date('Y%YW%U', t) end

local function version(w)
    local hoy = now()
    local week = asweek( hoy )
    local vers = which( week )
    local semana = 3600 * 24 * 7
    while vers == 0 do -- change in YEAR XXX
	hoy = hoy - semana
	week = asweek( hoy )
	vers = which( week )
    end
    w.week = week; w.vers = vers
    return w
end

local function dumpVERS(w)  end

local function newTicket( w )
    local uid = date('%FT%TP', now()) .. w.pid
    fd.reduce( w.args, fd.map( hd.args(keys, uid, w.id_tag) ), sql.into( tbname ), conn ) -- ids( uid, w.id_tag ), 

end

-- Let's build a ROUTER socket and use the 'inproc' protocol
--
-- this is a complex fn that depends on calling a second process that writes to the 'ferre.db',
-- after completion, it writes the changed values to current WEEK's database and updates
-- the running version
--

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection
--
local conn = assert( dbconn(asweek(now()), true) ) -- creates DB if not exists
fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(format(sql.newTable, tbname, schema)) end)

-- Compute latest version
--
version(VERS) -- latest version for UPDATES

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers) -- print latest version

dump(DEST, asJSON(VERS)) -- write to hard-disk latest version for UPDATES

-- ZMQ server sockets
--
local CTX = context()

-- Connect to the server(s)
--
local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

-- XXX SUBS messages should be sent

print('Successfully connecto to:', DOWNSTREAM, '\n')
-- -- -- -- -- --
--
local results = assert(CTX:socket'PUSH')

assert(results:connect( UPSTREAM ))

print('Successfully connecto to:', UPSTREAM, '\n')
-- -- -- -- -- --
-- There are two types of subscriptions to events on 'tkts' or 'vers'
-- Replies are sent in JSON format
--
assert( pub.send( format('vers %s', asJSON(VERS)) ) )

--[[
local events = poll{tickets, updates}
while true do
    local j = events(TIMEOUT)
    if j == 1 then
	tickets.recv
    elseif j == 2 then
	updates.recv
    end
end
--]]

