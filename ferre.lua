
local fs = require'carlos.files'
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local st = require'carlos.string'

-- gsub('Ñ','&Ntilde;'):

local function encode( s ) return s:gsub('%s+$',''):gsub('%.+$',''):gsub('"', '&quot;') end

local function readIn( a )
    local desc, clave, precio, fecha = encode( a[3] ), a[10], a[20], a[23]
    return { clave, desc, precio, fecha }
end

local conn = sql.connect'ferre.db'

local datos = fs.dlmread('ferre.txt', '\t')

conn.exec'CREATE TABLE IF NOT EXISTS datos (clave PRIMARY KEY, desc, precio NUMBER, fecha)'

fd.slice( 100, datos, fd.map( readIn ), st.status(#datos), sql.into'datos', conn )


