#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'json'.encode -- require'carlos.json'.asJSON
local dbconn	= require'carlos.ferre'.dbconn
local dump	= require'carlos.files'.dump

local print = print

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil

local DEST = HOME .. '/json/people.json'

local conn = dbconn'personas'
local QRY = 'SELECT id, nombre FROM empleados'

dump( DEST, asJSON(fd.reduce(conn.query(QRY), fd.into, {})) )

conn.close()

