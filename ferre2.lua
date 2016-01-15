
local fs = require'carlos.files'
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local st = require'carlos.string'

local function encode( s ) return s:gsub('%.+',' '):gsub('Ñ','&Ntilde;'):gsub('"', '&quot;')
end

local function readIn( a )
    local desc, costol, costo, clave, u1, p1, u2, p2, u3, p3, fecha = encode( a[3] ), a[5], a[8], a[10], a[11], a[13], a[14], a[16], a[17], a[19], a[23]
    return { clave, desc, costol, costo, u1, p1, u2, p2, u3, p3, fecha }
end

local conn = sql.connect'ferre.db'

local datos = fs.dlmread('ferre.txt', '\t')

conn.exec'CREATE TABLE IF NOT EXISTS datosALL (clave PRIMARY KEY, desc, costol NUMBER, costo NUMBER, u1, p1 NUMBER, u2, p2 NUMBER, u3, p3 NUMBER, fecha)'

fd.slice( 100, datos, fd.map( readIn ), st.status(#datos), sql.into'datosALL', conn )


