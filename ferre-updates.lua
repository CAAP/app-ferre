-- Import Section
--
local socket	  = require'carlos.zmq'.socket
local server	  = require'carlos.zmq'.server
local format	  = require'string'.format
local sleep	  = require'lbsd'.sleep
local file_exists = require'lbsd'.file_exists
local sql 	  = require'carlos.sqlite'
local asJSON	  = require'carlos.json'.asJSON

local time = os.time
local date = os.date
local rand = math.random

local assert = assert
local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local UPDATES   = 'ipc://updates.ipc'
local TICKETS   = 'ipc://tickets.ipc'
local TIMEOUT   = 5000 -- 5 secs
local SUBS	= {'vers', 'tkts'}
local VERS      = {} -- week, vers
local TABS	= {tickets = 'uid, id_tag, clave, desc, costol NUMBER, unidad, precio NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER',
		   updates = 'vers INTEGER PRIMARY KEY, clave, campo, valor'}


--------------------------------
-- Local function definitions --
--------------------------------
--
local function sse( event, data )
    return format('%s event: %s\ndata: %s\n\n\n', event, event, data)
end

local function dbconn(path, create)
    local f = format('$HOME/db/%s.db', path)
    if create or file_exists(f) then
	return sql.connect(f)
    else
	return false, format('ERROR: File %q does not exists!', f)
    end
end

local function now() return time()-21600 end

local function asweek(t) return date('Y%YW%U', t) end

-- if db file exists and 'updates' tb exists then returns count
local function which( db )
    local conn = dbconn( db )
    if conn and conn.exists'updates' then
	return conn.count'updates'
    else return 0 end
end

local function connexec( conn, s ) return assert( conn.exec(s) ) end

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
-- Run the PUBlisher
--
local pub = socket'PUB'

assert( pub.bind(TICKETS) )
--
-- Database connection
--
local conn = assert( dbconn( asweek(now()), true ) )
fd.reduce(fd.keys(TABS), function(schema, tbname) connexec(format(sql.newTable, tbname, schema)) end)
--
-- Compute latest version
--
version(VERS) -- latest version for UPDATES

pub.send( sse('vers', asJSON(VERS)) ) -- publish latest version

print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers) -- print latest version

--updateVERS(VERS) -- write to hard-disk latest version for UPDATES

