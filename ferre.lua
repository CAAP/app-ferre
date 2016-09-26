#!/usr/local/bin/lua

local fs = require'carlos.files'
local fd = require'carlos.fold'
local sql = require'carlos.sqlite'
local st = require'carlos.string'
local mx = require'ferre.timezone'

local function escape( s ) return s:gsub('^"+',''):gsub('"+$',''):gsub('""', '"'):gsub('"', '\"') end

local function encode( s ) return s:upper():gsub('%s+$',''):gsub('%.+$','') end

local function asnum( x ) return math.tointeger(x) or x end

local function quot( s ) return tonumber(s) and s or (s:len() == 0 and s or s:gsub('""','"'):gsub('"','\"')) end

-- line: _, _, desc, _, costo, impuesto, descuento, _, _, clave, u1, _, p1, u2, _, p2, u3, _, p3, fecha
-- line: desc, costo, impuesto, descuento, _, _, clave, u1, _, p1, u2, _, p2, u3, _, p3, fecha
local function readIn( a )
    return { a[10], encode( escape(a[1]) ), asnum(a[6]), asnum(a[7]), asnum(a[8]), quot(a[11]), asnum(a[13]), quot(a[14]), asnum(a[16]), quot(a[17]), asnum(a[19]), a[23], 0 }
end

local conn = sql.connect'/db/ferre.db'

---[[

local datos = fs.dlmread('/cgi-bin/ferre/ferre/ferre.txt', '\t')

conn.exec'CREATE TABLE IF NOT EXISTS datos (clave PRIMARY KEY, desc, costo NUMBER, impuesto NUMBER, descuento NUMBER, u1, prc1 NUMBER, u2, prc2 NUMBER, u3, prc3 NUMBER, fecha, costol NUMBER)'
conn.exec'CREATE VIEW IF NOT EXISTS precios AS SELECT clave, desc, fecha, u1, ROUND(prc1*costol/1e4,2) precio1, u2, ROUND(prc2*costol/1e4,2) precio2, u3, ROUND(prc3*costol/1e4,2) precio3 FROM datos'

conn.exec'CREATE INDEX IF NOT EXISTS busq_desc ON datos (desc ASC)'

fd.slice( 100, datos, fd.map(readIn), st.status(#datos), sql.into'datos', conn )

conn.exec'UPDATE datos SET costol = costo*(100+impuesto)*(100-descuento) WHERE costo > 0'

-- FALTANTES & more

conn.exec'CREATE TABLE IF NOT EXISTS faltantes (clave PRIMARY KEY, faltante INTEGER, fecha)'

conn.exec'INSERT INTO faltantes SELECT clave, 0, fecha FROM datos'

conn.exec'CREATE TABLE IF NOT EXISTS ubicacion (clave PRIMARY KEY, gps)' -- localizacion

conn.exec'INSERT INTO ubicacion SELECT clave, SUBSTR(desc, 1, 4) FROM datos'

conn.exec'CREATE TABLE IF NOT EXISTS cambios (clave PRIMARY KEY, version INTEGER, fecha)'

conn.exec'INSERT INTO cambios SELECT clave, 0, fecha FROM datos'

conn.exec'CREATE TABLE IF NOT EXISTS categorias (clave, obs)'

print''


conn.exec'CREATE TABLE IF NOT EXISTS empleados ( id INTEGER PRIMARY KEY, nombre, salario_hora )'

local nombres = {'Alberto', 'Alfonso', 'Adrian', 'Arturo', 'Carlos', 'Ernesto', 'Manuel', 'Rafa', 'Sergio'}

fd.slice( 10, nombres, fd.map(function(x,i) return {i, x, 23.15} end), sql.into'empleados', conn )

print''

--]]

-- line: _, razonsocial, rfc, ciudad, colonia, cp, correo, calle, noint, noext, estado

local clientes = fs.dlmread('/cgi-bin/ferre/ferre/clientes.txt', '\t')

fd.reduce( clientes, function(a) table.remove(a, 1) end )

conn.exec'CREATE TABLE IF NOT EXISTS clientes (razonSocial, rfc PRIMARY KEY, correo, calle, noInterior, noExterior, cp, colonia, ciudad, estado)'

local remove = fd.map( function(a) a[8] = tonumber(a[8]) and a[8] or a[8]:gsub('\\N', ''); a[6] = tonumber(a[6]) and a[6] or a[6]:gsub('\\N', ''); return a end )

local order = fd.map( function(a) return { a[1], a[2], a[6], a[7], a[8], a[9], (math.tointeger(a[5]) and string.format('%05d', a[5]) or '00000'), a[4], a[3], a[10] } end )

fd.slice( 100, clientes, remove, order, st.status(#clientes), sql.into'clientes', conn )

print''

