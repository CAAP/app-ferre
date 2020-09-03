#! /usr/bin/env lua53

-- Import Section
--

local connect	  = require'carlos.sqlite'.connect
local fd	  = require'carlos.fold'
local posix	  = require'posix.signal'

local format	  = string.format
local env	  = os.getenv
local exit	  = os.exit
local print	  = print
local assert	  = assert

local HOY	  = os.date('%d-%b-%y', now())

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--

local PRECIOS	 = assert( connect':inmemory:' )

local PID	 = { A = 'caja' }

local STREAM	 = env'STREAM_IPC'

--------------------------------
-- Local function definitions --
--------------------------------
--


---------------------------------
-- Program execution statement --
---------------------------------
--
--

local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

-- -- -- -- -- --
--

do
    local path = aspath'ferre'
    assert( PRECIOS.exec(format('ATTACH DATABASE %q AS ferre', path)) )
    assert( PRECIOS.exec'CREATE TABLE datos AS SELECT * FROM ferre.datos' )
    assert( PRECIOS.exec'DETACH DATABASE ferre' )

    path = aspath'personas'
    PRECIOS.exec(format('ATTACH DATABASE %q AS people', path))
    fd.reduce(PRECIOS.query'SELECT * FROM empleados', fd.map(function(p) return p.nombre end), fd.into, PID)
    PRECIOS.exec'CREATE TABLE clientes AS SELECT * FROM people.clientes'
    PRECIOS.exec'DETACH DATABASE people'

    PRECIOS.exec'CREATE VIEW precios AS SELECT clave, desc, fecha, u1, ROUND(prc1*costol/1e4,2) precio1, u2, ROUND(prc2*costol/1e4,2) precio2, u3, ROUND(prc3*costol/1e4,2) precio3, PRINTF("%d", costol) costol, uidSAT, proveedor, uidPROV FROM datos'

    print('items in datos:', PRECIOS.count'datos', '\n')
    print('items in precios:', PRECIOS.count'precios', '\n')
end

-- -- -- -- -- --
--

--
--
-- Initilize server(s)

local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:linger(0) )

assert( tasks:set_id'DB' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

-- -- -- -- -- --
--

while true do

    print'+\n'

    pollin{tasks}

    if tasks:events() == 'POLLIN' then



    end

end
