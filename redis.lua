local redis = require'redis'

local client = redis.connect('127.0.0.1', '6379')

assert( client:ping() )

local FRTS	 = {'apple', 'apricot', 'avocado', 'banana', 'berry', 'cherry', 'coconut', 'cucumber', 'fig', 'grape', 'raisin', 'guava', 'pepper', 'corn', 'plum', 'kiwi', 'lemon', 'lime', 'lychee', 'mango', 'melon', 'olive', 'orange', 'durian', 'longan', 'pea', 'peach', 'pear', 'prune', 'pine', 'pomelo', 'pome', 'quince', 'rhubarb', 'mamey', 'soursop', 'granate', 'sapote'}

client:sadd('app:fruits', table.unpack(FRTS))

client:sadd('app:dirty', 'clave', 'tbname', 'fruit')

client:sadd('app:istkt', 'ticket', 'presupuesto')

client:sadd('app:isstr', 'desc', 'fecha', 'proveedor', 'gps', 'u1', 'u2', 'u3', 'uidPROV')

client:sadd('app:toll', 'costo', 'impuesto', 'descuento', 'rebaja')

client:sadd('app:precios', 'prc1', 'prc2', 'prc3')

client:sadd('app:tabs', 'tabs', 'delete', 'msgs', 'pins', 'login', 'CACHE')

client:sadd('app:vers', 'vers', 'CACHE')


