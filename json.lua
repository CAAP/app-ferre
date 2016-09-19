#!/usr/local/bin/lua

local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'/db/ferre.db'

local function quot(x) return tonumber(x) and (math.tointeger(x) or x) or string.format('%q',x) end

local JSON = {'clave', 'version', 'desc', 'fecha', 'precio1', 'u1', 'precio2', 'u2', 'precio3', 'u3'}

local function tovec(a)
    local ret = fd.reduce( JSON, fd.map(function(k) return quot(a[k] or '') end), fd.into, {} )
    return string.format('[%s]' , table.concat(ret, ', '))
end

local function data()
    local N = conn.count'precios'
    local QRY = "SELECT * FROM precios, cambios WHERE desc NOT LIKE 'VV%' AND precios.clave = cambios.clave ORDER BY desc"
    local items = fd.reduce( conn.query(QRY), fd.map( tovec ), st.status(N), fd.into, {} ) -- fd.map( ntilde ),  
    local keys = table.concat(fd.reduce(JSON, fd.map( quot ), fd.into, {}), ', ')
    fs.dump('/htdocs/app-ferre/ferre.json', string.format('[[%s], [%s]]', keys, table.concat(items, ', ')))
end

data()

