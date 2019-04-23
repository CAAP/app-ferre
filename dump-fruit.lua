#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local stream	= require'carlos.ferre'.stream

local open	= io.open
local concat	= table.concat
local unpack	= table.unpack
local format	= string.format
local assert	= assert

local HOME	= require'carlos.ferre'.HOME
local arg	= arg

_ENV =  nil

assert( #arg >= 3, 'At least 3 args must be given!')

local fruit, week, vers = unpack(arg)

local DEST = HOME .. '/ventas/json'

local FIN  = open(format('%s/%s.json', DEST, fruit), 'w')

    FIN:write'['
    FIN:write( concat(fd.reduce(stream(week, vers), fd.into, {}), ',\n') )
    FIN:write']'
    FIN:close()

