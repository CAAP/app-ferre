#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local dbconn	= require'carlos.ferre'.dbconn

local open	= io.open
local concat	= table.concat

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil

local DEST = HOME .. '/ventas/json/people.json'

local conn = dbconn'personas'
local QRY = 'SELECT id, nombre FROM empleados'

local FIN  = open(DEST, 'w')

    FIN:write'['
    FIN:write( concat(fd.reduce(conn.query(QRY), fd.map(asJSON), fd.into, {}), ', ') )
    FIN:write']'
    FIN:close()

