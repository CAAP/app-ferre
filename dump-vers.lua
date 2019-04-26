#! /usr/bin/env lua53

local dbconn	= require'carlos.ferre'.dbconn
local asweek	= require'carlos.ferre'.asweek
local now	= require'carlos.ferre'.now
local asJSON	= require'carlos.json'.asJSON

local assert	= assert

local SEMANA	= 3600 * 24 * 7

local print	= print

_ENV =  nil

-- if db file exists and 'updates' tb exists then returns count
local function which( db )
    local conn = assert( dbconn( db ) )
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
    return asJSON{week=week, vers=vers}
end

print( version() )