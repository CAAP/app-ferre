#! /usr/bin/env lua53

-- Import Section
--
local fd	  = require'carlos.fold'

local dbconn	  = require'carlos.ferre'.dbconn
local asJSON	  = require'carlos.json'.asJSON
local connect 	  = require'carlos.sqlite'.connect
local file_exists = require'carlos.bsd'.file_exists
local socket	  = require'carlos.zmq'.socket

local open	  = io.open
local env	  = os.getenv
local concat	  = table.concat
local assert	  = assert

local print	  = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local PRECIOS   = env'HOME' .. '/db/ferre.db'
local DEST	= '/var/www/htdocs/app-ferre/ventas/json/precios.json'
local WEEK	= 'ipc://week.ipc'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function nulls(w)
    if w.precio2 == 0 then w.precio2 = nil end
    if w.precio3 == 0 then w.precio3 = nil end
    return w
end
---------------------------------
-- Program execution statement --
---------------------------------
--
local conn = dbconn(PRECIOS)
local QRY = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'
local FIN = open(DEST, 'w')

print'\nWriting data to file ...\n'
FIN:write'['
FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(nulls), fd.map(asJSON), fd.into, {}), ', ') )
FIN:write']'

FIN:close()

