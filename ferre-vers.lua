#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local unveil		= require'carlos.bsd'.unveil
local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local cache		= require'carlos.ferre'.cache
local dbconn		= require'carlos.ferre'.dbconn
local connexec		= require'carlos.ferre'.connexec
local decode		= require'carlos.ferre'.decode
local now		= require'carlos.ferre'.now
local newTable    	= require'carlos.sqlite'.newTable
local dump		= require'carlos.files'.dump

local format	= require'string'.format
local concat 	= table.concat
local open	= io.open
local date	= os.date
local assert	= assert

local print	= print

--unveil(os.getenv'HOME'..'/db', 'r')

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc'
local UPSTREAM	 = 'ipc://upstream.ipc'
local SEMANA	 = 3600 * 24 * 7
local QUERY 	 = 'SELECT * FROM updates %s'
local ROOT	 = '/var/www/htdocs/app-ferre/ventas/json'
local DEST	 = ROOT .. '/version.json'
local DEST_PRC	 = ROOT .. '/precios.json'
local DEST_PPL 	 = ROOT .. '/people.json'

local SUBS	 = {'adjust', 'version', 'CACHE', 'KILL'} -- people
local CACHE	 = cache'Hi VERS'

--unveil(ROOT, 'rw')

--------------------------------
-- Local function definitions --
--------------------------------
--
-- Functions to compute the current/ongoing version
-- based on the latest WEEK file on existence
--
local function asweek(t) return date('Y%YW%U', t) end

local function backintime(week, t) while week < asweek(t) do t = t - 3600*24*7 end; return t end

-- if db file exists and 'updates' tb exists then returns count
local function which( db )
    local conn = dbconn( db )
    if conn and conn.exists'updates' then
	return conn.count'updates'
    else return 0 end
end

local function version()
    local hoy = now()
    local week = asweek( hoy )
    local vers = which( week )
    while vers == 0 do -- change in YEAR XXX
	hoy = hoy - SEMANA
	week = asweek( hoy )
	vers = which( week )
--	if week:match'W00' then break end
    end
    return {week=week, vers=vers}
end

-- Functions to 
--
-- remove 'vers' since it's an extra event in itself and add arg 'store'
local function prepare(w)
    w.vers = nil
    w.store = 'PRICE'
    return w
end

local function fromWeek(week, vers)
    local conn =  dbconn(week)
    local clause = vers > 0 and format('WHERE vers > %d', vers) or ''
    local N = conn.count('updates', clause)

    if N > 0 then
	local data = fd.reduce(conn.query(format(QUERY, clause)), fd.map(prepare), fd.map(asJSON), fd.into, {})
	data[#data+1] = asJSON{vers=conn.count('updates'), week=week, store='VERS'}
	return concat(data, ',\n')
    end
end

-- ITERATIVE procedure AWESOME
local function nextWeek(t) return {t=t+SEMANA, vers=0} end

local function stream(week, vers)
    local function iter(WEEK, o)
	local w = asweek( o.t )
	if w > WEEK then return nil
	else return nextWeek(o.t), fromWeek(w, o.vers) end
    end
    return function() return iter, asweek(now()), {t=backintime(week, now()), vers=vers} end
end

-- find all updates that need to be sent to a specific peer & send them all
local function adjust(fruit, week, vers)
    local FIN = open(format('%s/%s.json', ROOT, fruit), 'w')
    FIN:write'['
    FIN:write( concat(fd.reduce(stream(week, vers), fd.into, {}), ',\n') )
    FIN:write']'
    FIN:close()
    return 'Updates stored and dumped'
end

-- DUMP
--local function myVersion() return format('version %s', asJSON(VERS)) end

local function dumpVERS(v) dump(DEST, v) end

local function nulls(w)
    if w.precio2 == 0 then w.precio2 = nil end
    if w.precio3 == 0 then w.precio3 = nil end
    return w
end

local function dumpPRICE()
    local conn =  dbconn'ferre'
    local QRY = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'
    local FIN = open(DEST_PRC, 'w')

print'\nWriting data to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(nulls), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end

local function dumpPEOPLE(conn)
    local conn = dbconn'ferre'
    local QRY = 'SELECT id, nombre FROM empleados'
    local FIN = open(DEST_PPL, 'w')

print'\nWriting people to file ...\n'
    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()
end

local function getVersion()
    local VERS = version()
    local v = asJSON(VERS)
    dumpVERS( v )
    dumpPRICE()
    CACHE.store('vers' ,format('version %s', v))
    print('\n\tWeek:', VERS.week, '\n\tVers:', VERS.vers, '\n')
    return v
end

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
-- Compute latest version & Dump data
-- additionally sends SSE with latest version in case of UPGRADE!!!
-- could be solved otherwise XXX like in the admin-app
--
msgr:send_msg(format('version %s', getVersion()))

--
-- -- -- -- -- --
-- Run loop
--
while true do
print'+\n'
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'VERS' then
	    msgr:send_msg('Bye VERS')
	    break
	end
    end
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
    end
    if cmd == 'version' then
	msgr:send_msg(format('version %s', getVersion()))
    end
    if cmd == 'adjust' then
	local  cmd, o = decode(msg) -- fruit, week, vers
	print( adjust(o.fruit, o.week, o.vers), '\n' )
	msgr:send_msg(format('%s adjust %s.json', o.fruit, o.fruit))
    end
end


--[[
--]]
