#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'json'.encode
local dbconn	= require'carlos.ferre'.dbconn
local dump	= require'carlos.files'.dump

local print = print
local assert = assert

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil


local conn = assert( dbconn'cfdi' )

---------------------------------------

local DEST = HOME .. '/json/units.json'

local QRY = 'SELECT unidad, desc FROM unidades'

dump( DEST, asJSON(fd.reduce(conn.query(QRY), fd.into, {})) )

---------------------------------------

conn.close()


