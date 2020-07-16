#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'json'.encode -- require'carlos.json'.asJSON
local dbconn	= require'carlos.ferre'.dbconn
local dump	= require'carlos.files'.dump

local print = print
local assert = assert

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil


local conn = assert( dbconn'personas' )

---------------------------------------

local DEST = HOME .. '/json/people.json'

local QRY = 'SELECT id, nombre, pin FROM empleados'

dump( DEST, asJSON(fd.reduce(conn.query(QRY), fd.into, {})) )

---------------------------------------

DEST = HOME .. '/json/proveedores.json'

QRY = 'SELECT * FROM proveedores ORDER BY nombre ASC'

dump( DEST, asJSON(fd.reduce(conn.query(QRY), fd.into, {})) )

---------------------------------------

DEST = HOME .. '/json/clientes.json'

QRY = 'SELECT * FROM clientes ORDER BY rfc ASC'

dump( DEST, asJSON(fd.reduce(conn.query(QRY), fd.into, {})) )

---------------------------------------


conn.close()


