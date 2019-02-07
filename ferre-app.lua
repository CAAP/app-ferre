
-- Import Section
local bsd  = require'carlos.bsd'
local fd   = require'carlos.fold'
local sql  = require'carlos.sqlite'
local json = require'carlos.json'

local iopen = require'carlos.io'.open
local dump = require'carlos.files'.dump
local socket = require'carlos.zmq'.socket
local poll = require 'lzmq'.pollin
local context = require'lzmq'.context
local time = os.time
local date = os.date

local format = require'string'.format
local assert = assert

local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local TIMEOUT = 2000 -- 2 secs
local VERS = {} -- week, vers
local TABS = {tickets = 'uid, id_tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
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
-- accepts name of db and adds absolute path,
-- creating it if required, otherwise it checks
-- whether path already exists, always returning
-- the sql connection or error
local function dbconn(path, create)
    local f = format('/home/sg/db/%s.db', path) -- XXX alberto
    if create or bsd.file_exists(f) then
	return sql.connect(f)
    else
	return false, format('ERROR: File %q does not exists!', f)
    end
end

local function connexec( conn, s ) return assert( conn.exec(s) ) end

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
--	if week:match'W00' then break end
    end
    w.week = week; w.vers = vers
    return w
end

local function updateVERS(w) dump("/var/www/htdocs/app-ferre/ventas/json/version.json", json.asJSON(w)) end

local function newTicket( w )
    local uid = date('%FT%TP', now()) .. w.pid
    fd.reduce( w.args, fd.map( hd.args(keys, uid, w.id_tag) ), sql.into( tbname ), conn ) -- ids( uid, w.id_tag ), 

end

local function asJSON() return format('data: %s', json.asJSON()) end -- XXX used only once in next fn

local function sse( w ) -- XXX not used even once
    if not(w) then return ':empty' end
    local event = w.event
    w.event = nil
    local ret = w.ret or {}
    w.ret = nil
    local data = w.data or asJSON( w )
    ret[#ret+1] = 'event: ' .. event
    ret[#ret+1] = 'data: ['
    ret[#ret+1] = data
    ret[#ret+1] = 'data: ]'
    ret[#ret+1] = '\n'
    return table.concat( ret, '\n')
end

-- Let's build a ROUTER socket and use the 'inproc' protocol
--
-- this is a complex fn that depends on calling a second process that writes to the 'ferre.db',
-- after completion, it writes the changed values to current WEEK's database and updates
-- the running version
--


local function updates(skt)
    local rtr = socket('ROUTER', ctx)
    assert(rtr.bind'ipc://updates.ipc')

end

local function tickets(ctx)
    local rtr = socket('ROUTER', ctx)
    assert(rtr.bind'ipc://tickets.ipc')

end


---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection
--
local conn = assert( dbconn(asweek(now()), true) )
fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(format(sql.newTable, tbname, schema)) end)

-- Compute latest version
--
version(VERS) -- latest version for UPDATES

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers) -- print latest version

updateVERS(VERS) -- write to hard-disk latest version for UPDATES

-- ZMQ server sockets
--
local ctx = context()

local tickets = socket('ROUTER', ctx)
assert(tickets.bind'ipc://tickets.ipc') -- changes are distributed to 'selected' peers

local updates = socket('REP', ctx)
assert(updates.bind'ipc://updates.ipc') -- changes are distributed to 'all' peers

local pub = socket('XPUB', ctx)
assert(pub.bind'ipc://week.ipc') -- every change to the underlying DB is distributed here

-- Initialize the server
-- There are two types of subscriptions to events on 'tkts' or 'vers'
-- Replies are sent in JSON format
--
assert( pub.send( format('vers %s', json.asJSON(VERS)) ) )

local events = poll{tickets, updates}

while true do
    local j = events(TIMEOUT)
    if j == 1 then
	tickets.recv
    elseif j == 2 then
	updates.recv
    end
end

