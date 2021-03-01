#! /usr/bin/env lua53

local fd	= require'carlos.fold'
local dbconn	= require'carlos.ferre'.dbconn
local asweek	= require'carlos.ferre'.asweek
local now	= require'carlos.ferre'.now
local dump	= require'carlos.files'.dump

local json	= require'json'.encode
local rconnect	= require'redis'.connect
local insert	= table.insert
local assert	= assert

local HOME	= require'carlos.ferre'.HOME

local WEEK	= asweek(now())

_ENV =  nil

local DEST 	= HOME .. '/json/precios.json' -- '/ventas/json/precios.json'
local client	= assert( rconnect('127.0.0.1', '6379') )

local function nulls(w)
    if w.precio2 == 0 then w.precio2 = nil end
    if w.precio3 == 0 then w.precio3 = nil end
    return w
end

local conn = dbconn'ferre'
local QRY  = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'

local vers = {version=client:get'app:updates:version', week=WEEK}

local ret = fd.reduce(conn.query(QRY), fd.map(nulls), fd.into, {})
insert(ret, vers)
dump(DEST, json(ret))

