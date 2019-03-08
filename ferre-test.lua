#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local asJSON		= require'carlos.json'.asJSON
local dbconn		= require'carlos.ferre'.dbconn

local format	= require'string'.format
local time	= os.time
local date	= os.date

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local VERS	 = {} -- week, vers

local SEMANA	 = 3600 * 24 * 7
local UP_QUERY = 'SELECT * FROM updates %s'


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

local function fromWeek(week, vers)
    local conn =  dbconn(week)
    local clause = format('WHERE vers > %d', vers)

    if conn.count('updates', clause) > 0 then
	return fd.reduce(conn.query(format(UP_QUERY, clause)), fd.map(asJSON), fd.into, {})
    else
	return ':empty'
    end
end

local function backintime(week, t)
    while week < asweek(t) do t = t - 3600*24*7 end
    return t
end

-- ITERATIVE procedure AWESOME
local function nextWeek(t) return {t=t + SEMANA, vers=0} end

local function adjust(week, vers)
    local function iter(WEEK, o)
	local w = asweek( o.t )
	if w > WEEK then return nil
	else return nextWeek(o.t), fromWeek(week, o.vers) end
    end
    return iter, VERS.week, {t=backintime(week, now()), vers=vers}
end

version(VERS) -- latest version for UPDATES

print('week:', VERS.week, '\tvers:', VERS.vers)

return adjust


