#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local dbconn	= require'carlos.ferre'.dbconn
local uid2week	= require'carlos.ferre'.uid2week
local asnum	= require'carlos.ferre'.asnum
local asweek	= require'carlos.ferre'.asweek
local now	= require'carlos.ferre'.now
local asJSON	= require'json'.encode
local dump	= require'carlos.files'.dump

local concat	= table.concat
local remove	= table.remove
local insert	= table.insert
local format	= string.format
local date	= os.date
local assert	= assert

local print	= print

local HOME	= require'carlos.ferre'.HOME

local cmd	= arg[1]
local fruit	= arg[2]
local uid	= arg[3]

_ENV =  nil

local QTKT	= 'SELECT uid, tag, clave, qty, rea, totalCents, prc "precio" FROM tickets WHERE uid LIKE %q'

local QUID	 = 'SELECT uid, SUBSTR(uid, 12, 5) time, SUM(qty) count, ROUND(SUM(totalCents)/100.0, 2) total, tag FROM tickets WHERE tag NOT LIKE "factura" AND uid %s %q GROUP BY uid'

local CLAUSE	 = 'WHERE tag NOT LIKE "factura" AND uid %s %q'

local path = format('%s/caja/json/%s-feed.json', HOME, fruit)

local function toCents(w)
    if w.total then w.total = format('%.2f', w.total) end
    return w
end


local function dumping(conn, qry)
    dump(path, asJSON(fd.reduce(conn.query(qry), fd.map(toCents), fd.into, {}))) -- fd.map(addName), 
end

local function switch(cmd)
    if cmd == 'uid' then
	local conn = assert( dbconn( uid2week(uid) ) )
	dumping( conn, format(QTKT, uid) )

    elseif cmd == 'feed' then
	local t = date('%FT%T', now()):sub(1, 10)
	local conn = assert( dbconn( asweek(now()) ))
	if conn.count( 'tickets', format(CLAUSE, '>', t) ) > 0 then
	    dumping( conn, format(QUID, '>', t) )
	end

    elseif cmd == 'ledger' then
	local conn = assert( dbconn( uid2week(uid) ))
	if conn.count( 'tickets', format(CLAUSE, 'LIKE', uid..'%') ) > 0 then
	    dumping( conn, format(QUID, 'LIKE', uid..'%') )
	end
    end
end

switch(cmd)


--[[
local function addName(o)
    local pid = asnum(o.uid:match'P([%d%a]+)')
    o.nombre = pid and PEOPLE[pid] or 'NaP';
    return o
end
--]]


