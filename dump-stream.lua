#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local stream	= require'carlos.ferre'.stream
local dump	= require'carlos.files'.dump
local asJSON	= require'json'.encode

local unpack	= table.unpack
local format	= string.format
local assert	= assert

local HOME	= require'carlos.ferre'.HOME
local arg	= arg

_ENV =  nil

assert( #arg >= 3, 'At least 3 args must be given!')

local fruit, week, vers = unpack(arg)

local DEST = HOME .. '/ventas/json'

dump(format('%s/%s-stream.json', DEST, fruit), asJSON(fd.reduce(stream(week, vers), fd.flat, {})))

