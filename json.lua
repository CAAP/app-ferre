local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'ferre.db'

local JSON = '{clave:"$clave", desc:"$desc", precio1:$precio1, precio2:$precio2, precio3:$precio3, unidad1:"$u1", unidad2:"$u2", unidad3:"$u3", fecha:"$fecha"}'

local function tostr( a ) a.u2 = a.u2 or ''; a.u3 = a.u3 or ''; return JSON:gsub( '%$(%w+)', a ) end

local N = conn.count'datosALL'

local QRY = "SELECT *, ROUND(costol*impuesto*descuento*p1,2) precio1, ROUND(costol*impuesto*descuento*p2,2) precio2, ROUND(costol*impuesto*descuento*p3,2) precio3 FROM datosALL"

local items = fd.reduce( conn.query(QRY), fd.map( tostr ), st.status(N), fd.into, {} )

fs.dump('ferre.json', '[' .. table.concat(items, ',') .. ']')
