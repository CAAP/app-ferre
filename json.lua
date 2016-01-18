local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'ferre.db'

local JSON = '{clave:"$clave", desc:"$desc", precio1:$precio1, precio2:$precio2, precio3:$precio3, unidad1:$u1, unidad2:$u2, unidad3:$u3, fecha:"$fecha"}'

local function tostr( a ) return JSON:gsub( '%$(%w+)', a ) end

local N = conn.count'datosALL'

local QRY = "SELECT *, costol*impuesto*descuento*p1 precio1, costol*impuesto*descuento*p2 precio2, costol*impuesto*descuento*p3 precio3 FROM datosALL"

local items = fd.reduce( conn.query(QRY), fd.map( tostr ), st.status(N), fd.into, {} )

fs.dump('ferre.json', '[' .. table.concat(items, ',') .. ']')
