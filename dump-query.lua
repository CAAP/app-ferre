#! /usr/bin/env lua53

local first	= require'carlos.fold'.first

local dbconn	= require'carlos.ferre'.dbconn
local asJSON	= require'carlos.json'.asJSON

local format	= string.format
local assert	= assert
local print	= print

local arg	= arg

_ENV =  nil

local msg = assert( arg[1] )

local QDESC	 = 'SELECT desc FROM precios WHERE desc LIKE %q ORDER BY desc LIMIT 1'

local function byDesc(conn, s)
    local qry = format(QDESC, s:gsub('*', '%%')..'%%')
    local o = first(conn.query(qry), function(x) return x end) or {desc=''} -- XXX can return NIL
    return o.desc
end

local function byClave(conn, s)
    local qry = format('SELECT * FROM  datos WHERE clave LIKE %q LIMIT 1', s)
    return asJSON( first(conn.query(qry), function(x) return x end) )
end

local fruit = msg:match'fruit=(%a+)'

local PRECIOS = assert( dbconn'ferre' )

if msg:match'desc' then

    local ret = msg:match'desc=([^&]+)' -- potential error if '&' included
    ret = byDesc(PRECIOS, ret)
    print(ret)

elseif msg:match'clave' then

    local ret = msg:match'clave=([%a%d]+)' -- potential error if '&' included
    ret = byClave(PRECIOS, ret)
    print(ret)

end

