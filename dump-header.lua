#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local dbconn	= require'carlos.ferre'.dbconn
local asJSON	= require'json'.encode

local concat	= table.concat
local remove	= table.remove
local insert	= table.insert
local format	= string.format
local assert	= assert

local print	= print

_ENV =  nil

local function getHeader()
    local conn = dbconn'ferre'
    local ret = conn.header'datos'
--    remove(ret) -- faltante
    insert(ret, 2, remove(ret)) -- proveedor
    remove(ret) -- uidSAT
    insert(ret, 6, remove(ret)) -- rebaja
    remove(ret) -- costol
    return format('%s %s', 'header', asJSON(ret))
end

print( getHeader() )

