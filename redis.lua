local redis = require'redis'
local concat = table.concat

local client = redis.connect('127.0.0.1', '6379')

assert( client:ping() )

local FRTS	 = {'apple', 'apricot', 'avocado', 'banana', 'berry', 'cherry', 'coconut', 'cucumber', 'fig', 'grape', 'raisin', 'guava', 'pepper', 'corn', 'plum', 'kiwi', 'lemon', 'lime', 'lychee', 'mango', 'melon', 'olive', 'orange', 'durian', 'longan', 'pea', 'peach', 'pear', 'prune', 'pine', 'pomelo', 'pome', 'quince', 'rhubarb', 'mamey', 'soursop', 'granate', 'sapote'}

local ESTREAM	 = concat({"Content-Type: text/event-stream",
"Connection: keep-alive", "Cache-Control: no-cache",
"Access-Control-Allow-Origin: *", "Access-Control-Allow-Methods: GET"}, "\r\n")

local EGET	 = concat({"Content-Type: text/plain",
"Cache-Control: no-cache", "Access-Control-Allow-Origin: *",
"Access-Control-Allow-Methods: GET"}, "\r\n")

--- *LIST* ---
assert( client:lpush('const:fruits', table.unpack(FRTS)) )

--- *SET* ---
assert( client:sadd('const:dirty', 'clave', 'tbname', 'fruit') )

assert( client:sadd('const:istkt', 'ticket', 'presupuesto') ) -- 'surtir', 'tabs'

assert( client:sadd('const:isstr', 'desc', 'fecha', 'proveedor', 'gps', 'u1', 'u2', 'u3', 'uidPROV') )

assert( client:sadd('const:toll', 'costo', 'impuesto', 'descuento', 'rebaja') )

assert( client:sadd('const:precios', 'prc1', 'prc2', 'prc3') )

--- *KEY* ---
assert( client:set('sql:costol', 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)') )

assert( client:set('tcp:sse', ESTREAM) )

assert( client:set('tcp:get', EGET) )

--- *HASH* ---
assert( client:hset('sql:week', 'tickets', 'uid, tag, prc, clave, desc, costol NUMBER, unidad, precio NUMBER, unitario NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER, uidSAT, nombre') )

assert( client:hset('sql:week', 'updates', 'vers INTEGER PRIMARY KEY, clave, msg'))

assert( client:hset('sql:week', 'facturas', 'uid, fapi PRIMARY KEY NOT NULL, rfc NOT NULL, sat NOT NULL'))

assert( client:hset('sql:week', 'uids', 'CREATE TEMP VIEW IF NOT EXISTS uids AS SELECT uid, SUBSTR(uid, 12, 5) time, COUNT(uid) count, ROUND(SUM(totalCents)/100.0, 2) total, tag, nombre FROM tickets WHERE tag NOT LIKE "factura" GROUP BY uid') )

assert( client:hset('sql:week', 'lpr', 'CREATE TEMP VIEW IF NOT EXISTS lpr AS SELECT desc, clave, qty, rea, ROUND(unitario, 2) unitario, unidad, ROUND(totalCents/100.0, 2) subTotal, uid FROM tickets') )

assert( client:hset('sql:week', 'sales', 'CREATE TEMP VIEW IF NOT EXISTS sales AS SELECT SUBSTR(uid,1,10) day, SUBSTR(uid,12,5) hour, ((SUBSTR(uid,12,2)-9)*60 + SUBSTR(uid, 15, 2))/10 mins, uid, nombre, totalCents, qty FROM tickets') )

