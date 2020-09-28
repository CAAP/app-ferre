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

assert( client:lpush('const:fruits', table.unpack(FRTS)) ) -- *LIST*

assert( client:sadd('const:dirty', 'clave', 'tbname', 'fruit') )

assert( client:sadd('const:istkt', 'ticket', 'presupuesto') ) -- 'surtir', 'tabs'

assert( client:sadd('const:isstr', 'desc', 'fecha', 'proveedor', 'gps', 'u1', 'u2', 'u3', 'uidPROV') )

assert( client:sadd('const:toll', 'costo', 'impuesto', 'descuento', 'rebaja') )

assert( client:sadd('const:precios', 'prc1', 'prc2', 'prc3') )


assert( client:set('sql:costol', 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)') )

assert( client:set('sql:tickets', 'uid, tag, prc, clave, desc, costol NUMBER, unidad, precio NUMBER, unitario NUMBER, qty INTEGER, rea INTEGER, totalCents INTEGER, uidSAT, nombre') )

assert( client:set('sql:updates', 'vers INTEGER PRIMARY KEY, clave, msg') )

assert( client:set('sql:facturas', 'uid, fapi PRIMARY KEY NOT NULL, rfc NOT NULL, sat NOT NULL') )


assert( client:set('tcp:sse', ESTREAM) )

assert( client:set('tcp:get', EGET) )


-- client:sadd('app:tabs', 'tabs', 'delete', 'msgs', 'pins', 'login', 'CACHE')

-- client:sadd('app:vers', 'vers', 'CACHE')

