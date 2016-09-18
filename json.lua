#!/usr/local/bin/lua

local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'/db/ferre.db'

local function quot(x) return tonumber(x) or string.format('%q',x) end

local JSON = {'clave', 'desc', 'fecha', 'precio1', 'u1', 'precio2', 'u2', 'precio3', 'u3'}

local function tovec1(a)
    local ret = fd.reduce( JSON, fd.map(function(k) return (a[k] and quot(a[k]) or '""') end), fd.into, {} )
    local costol = a.costo * (100 - a.descuento) * (100 + a.impuesto)
    local function precio(y) return string.format('%.2f', costol*y/1e4) end
    ret[1] = math.tointeger(ret[1]) or ret[1]
    ret[4], ret[6], ret[8] = (a.prc1), (a.prc2), (a.prc3)
    return '[' .. table.concat(ret, ', ') .. ']'
end

local function tovec(a)
    local ret = fd.reduce( JSON, fd.map(function(k) return tonumber(a[k] or '') or quot(a[k] or '') end), fd.into, {} )
    ret[1] = math.tointeger(ret[1]) or ret[1]
    return '[' .. table.concat(ret, ', ') .. ']'
end

local function data()
    local N = conn.count'precios'
    local QRY = "SELECT * FROM precios ORDER BY desc"
    local items = fd.reduce( conn.query(QRY), fd.map( tovec ), st.status(N), fd.into, {} ) -- fd.map( ntilde ),  
    local keys = table.concat(fd.reduce(JSON, fd.map( quot ), fd.into, {}), ', ')
    fs.dump('/htdocs/app-ferre/ferre.json', '[[' .. keys ..'], [' .. table.concat(items, ', ') .. ']]')
end

data()

