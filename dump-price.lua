#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local dbconn	= require'carlos.ferre'.dbconn

local open	= io.open
local concat	= table.concat

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil

local DEST = HOME .. '/ventas/json/precios.json'

local function nulls(w)
    if w.precio2 == 0 then w.precio2 = nil end
    if w.precio3 == 0 then w.precio3 = nil end
    return w
end

local conn = dbconn'ferre'
local QRY  = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'

local FIN  = open(DEST, 'w')

    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(nulls), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()

