local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'ferre.db'

local JSON = {'clave', 'desc', 'fecha', 'precio1', 'precio2', 'precio3', 'u1', 'u2', 'u3'}

local function asstr(x) return tonumber(x) or '"'..x..'"' end

local function tostr(a)
    local ret = fd.reduce( JSON, fd.filter(function(k) return a[k] end), fd.map(function(k) return k..':'..asstr(a[k]) end), fd.into, {} )
    return '{' .. table.concat(ret, ', ') .. '}'
end

local N = conn.count'datosALL'

local QRY = "SELECT *, ROUND(costol*impuesto*descuento*p1,2) precio1, ROUND(costol*impuesto*descuento*p2,2) precio2, ROUND(costol*impuesto*descuento*p3,2) precio3 FROM datosALL"

local items = fd.reduce( conn.query(QRY), fd.map( tostr ), st.status(N), fd.into, {} )

fs.dump('ferre.json', '[' .. table.concat(items, ', ') .. ']')
