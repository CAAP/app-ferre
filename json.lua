local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local fs = require'carlos.files'
local st = require'carlos.string'

local conn = sql.connect'ferre.db'

local JSON = '{clave:"$clave", desc:"$desc", precio:$precio, fecha:"$fecha"}'

local function tostr( a ) return JSON:gsub( '%$(%w+)', a ) end

local N = conn.count'datos'


local items = fd.reduce( conn.query'SELECT * FROM datos', fd.map( tostr ), st.status(N), fd.into, {} )

fs.dump('ferre.json', '[' .. table.concat(items, ',') .. ']')
