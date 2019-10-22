#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local dbconn	= require'carlos.ferre'.dbconn
local asJSON	= require'json'.encode
local dump	= require'carlos.files'.dump

local remove	= table.remove
local insert	= table.insert
local format	= string.format

local print	= print

local HOME	= require'carlos.ferre'.HOME

_ENV =  nil

local DEST = HOME .. '/json/header.json'

local conn = dbconn'ferre'

local ret = conn.header'datos'

conn.close()

remove(ret) -- uidPROV
insert(ret, 2, remove(ret)) -- proveedor
remove(ret) -- uidSAT
insert(ret, 6, remove(ret)) -- rebaja
remove(ret) -- costol

dump( DEST, asJSON(ret) )

