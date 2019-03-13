#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local cache		= require'carlos.ferre'.cache
local dbconn		= require'carlos.ferre'.dbconn
local connexec		= require'carlos.ferre'.connexec
local newTable    	= require'carlos.sqlite'.newTable
local dump		= require'carlos.files'.dump

local format	= require'string'.format
local concat 	= table.concat
local open	= io.open
local time	= os.time
local date	= os.date
local assert	= assert

local print	= print

-- No more external access after this point
_ENV = nil -- or M

--XXX should enforce a read-only access by the OS XXX
--using "unveil" from carlos.bsd -> unveil(path, flags)
--unveil('$HOME/db', 'r')
--unveil(ROOT, 'rw')

-- Local Variables for module-only access
--
local SEMANA	 = 3600 * 24 * 7
local DEST	= '/var/www/htdocs/app-ferre/ventas/json/version.json'
--local DEST_PEOP	= '/var/www/htdocs/app-ferre/ventas/json/people.json'

local SUBS	 = {'adjust', 'version', 'CACHE', 'KILL'} -- people
local VERS	 = {} -- week, vers

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

local function fromWeek(week, vers)
    local conn =  dbconn(week)
    local clause = format('WHERE vers > %d', vers)
    local N = conn.count('updates', clause)

    if N > 0 then
	local data = fd.reduce(conn.query(format(UP_QUERY, clause)), fd.map(prepare), fd.map(asJSON), fd.into, {})
	data[#data+1] = asJSON{vers=N, week=week, store='VERS'}
	return data -- return concat(data, '\n')
    else
	return ':empty\n\n'
    end
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

-- DUMP
local function myVersion() return format('version %s', asJSON(VERS)) end

local function dumpVERS() dump(DEST_VERS, asJSON(VERS)) end

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

---------------------------------
-- Program execution statement --
---------------------------------
--
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
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'TABS' then
	    msgr:send_msg('Bye TABS')
	    break
	end
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
	goto FIN
    end
    
--    
    local pid = msg:match'pid=(%d+)'
    CACHE[cmd]( pid, msg )
    msgr:send_msg( msg )
    print(msg, '\n')
    ::FIN::
--

end

