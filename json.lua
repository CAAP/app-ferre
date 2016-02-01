local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'ferre.db'

local JSON = {'clave', 'desc', 'fecha', 'precio1', 'u1', 'precio2', 'u2', 'precio3', 'u3'}

local function quot(x) return tonumber(x) or '"'..x..'"' end

local function ntilde(a) a.desc = a.desc:gsub('&Ntilde;', 'Ñ'); return a end


local function tovec(a)
    local ret = fd.reduce( JSON, fd.map(function(k) return (a[k] or '') end), fd.into, {} )
    return '[' .. table.concat(ret, ', ') .. ']'
end

local N = conn.count'datosALL'

local QRY = "SELECT *, ROUND(costol*impuesto*descuento*p1,2) precio1, ROUND(costol*impuesto*descuento*p2,2) precio2, ROUND(costol*impuesto*descuento*p3,2) precio3 FROM datosALL ORDER BY desc"

local items = fd.reduce( conn.query(QRY), fd.map( ntilde ), fd.map( tovec ), st.status(N), fd.into, {} )

local keys = table.concat(fd.reduce(JSON, fd.map(quot), fd.into, {}), ', ')

fs.dump('ferre.json', '[[' .. keys ..'], [' .. table.concat(items, ', ') .. ']]')

