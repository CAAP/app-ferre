#!/usr/local/bin/lua

local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'/db/ferre.sql'

local function quot(x) return tonumber(x) or string.format('%q',x) end

local JSON = {'clave', 'desc', 'fecha', 'precio1', 'u1', 'precio2', 'u2', 'precio3', 'u3'}

--local function ntilde(a) a.desc = a.desc:gsub('&Ntilde;', 'Ñ'); return a end

local function tovec(a)
    local ret = fd.reduce( JSON, fd.map(function(k) return (a[k] and quot(a[k]) or '""') end), fd.into, {} )
    local costol = a.costo * (100 - a.descuento) * (100 + a.impuesto)
    local function precio(y) return string.format('%.2f', costol*y/1e4) end
    ret[1] = math.tointeger(ret[1]) or ret[1]
--    ret[2] = ret[2]:gsub('Ñ', '&#209;')
    ret[4], ret[6], ret[8] = precio(a.p1), precio(a.p2), precio(a.p3)
    return '[' .. table.concat(ret, ', ') .. ']'
end

local function data()
    local N = conn.count'datos'
    local QRY = "SELECT * FROM datos ORDER BY desc"
    local items = fd.reduce( conn.query(QRY), fd.map( tovec ), st.status(N), fd.into, {} ) -- fd.map( ntilde ),  
    local keys = table.concat(fd.reduce(JSON, fd.map( quot ), fd.into, {}), ', ')
    fs.dump('/htdocs/app-ferre/ferre.json', '[[' .. keys ..'], [' .. table.concat(items, ', ') .. ']]')
end

data()

