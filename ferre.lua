
local fs = require'carlos.files'
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local st = require'carlos.string'

-- gsub('Ñ','&Ntilde;'):

local function encode( s ) return s:gsub('%s+$',''):gsub('%.+$',''):gsub('"', '&quot;'):gsub('Ñ','&Ntilde;'):gsub('&','&amp;') end

local function quot(s) return tonumber(s) and s or s:gsub('"', '&quot;') end

local function getdate(s) local d,m,y = s:match('(%d+)/(%d+)/(%d+)'); return string.format('20%d-%02d-%02d',y,m,d) end

local function readIn( a )
    local desc, costol, impuesto, descuento, clave, u1, p1, u2, p2, u3, p3, fecha = encode( a[3] ), a[5], 1.0+a[6]/100.0, 1.0-a[7]/100.0, a[10], quot(a[11]), a[13], quot(a[14]), a[16], quot(a[17]), a[19], getdate(a[23])
    return { clave, desc, costol, impuesto, descuento, u1, p1, u2, p2, u3, p3, fecha }
end

local conn = sql.connect'ferre.db'

local datos = fs.dlmread('ferre.txt', '\t')

conn.exec'CREATE TABLE IF NOT EXISTS datosALL (clave PRIMARY KEY, desc, costol NUMBER, impuesto NUMBER, descuento NUMBER, u1, p1 NUMBER, u2, p2 NUMBER, u3, p3 NUMBER, fecha)'

fd.slice( 100, datos, fd.map( readIn ), st.status(#datos), sql.into'datosALL', conn )


