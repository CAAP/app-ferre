local fs = require'carlos.files'
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local st = require'carlos.string'

local function encode( s ) return string.format('%q', s:upper():gsub('%s+$',''):gsub('%.+$',''):gsub('Ñ','&Ntilde;'):gsub('ñ','&Ntilde;')) end

local function quot(s) return tonumber(s) and s or string.format('%q', s) end

local function getdate(s) local d,m,y = s:match('(%d+)/(%d+)/(%d+)'); return string.format('"20%02d-%02d-%02d"',y,m,d) end

-- line: _, _, desc, _, costo, impuesto, descuento, _, _, clave, u1, _, p1, u2, _, p2, u3, _, p3, fecha
local function readIn( a )
    return { quot(a[10]), encode(a[3]), a[5], a[6], a[7], quot(a[11]), a[13], quot(a[14]), a[16], quot(a[17]), a[19], getdate(a[23]) }
end

local conn = sql.connect'ferre.db'

local datos = fs.dlmread('ferre.txt', '\t')

conn.exec'CREATE TABLE IF NOT EXISTS datos (clave PRIMARY KEY, desc, costo NUMBER, impuesto NUMBER, descuento NUMBER, u1, p1 NUMBER, u2, p2 NUMBER, u3, p3 NUMBER, fecha)'

fd.slice( 100, datos, fd.map(readIn), st.status(#datos), sql.into'datos', conn )

conn.exec'CREATE TABLE IF NOT EXISTS empleados ( id INTEGER PRIMARY KEY, nombre )'

local nombres = {'Alberto', 'Arturo', 'Carlos', 'Ernesto', 'Jorge', 'Manuel', 'Rafa', 'Sergio'}

fd.slice( 50, nombres, fd.map(function(x,i) return {i-1, x} end), sql.into'empleados', conn )
