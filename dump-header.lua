#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local dbconn	= require'carlos.ferre'.dbconn

local concat	= table.concat
local remove	= table.remove
local insert	= table.insert
local format	= string.format
local assert	= assert

local print	= print

_ENV =  nil

local function escape(a) return fd.reduce(a, fd.map(function(x) return format('%q',x) end), fd.into, {}) end

local function getHeader()
    local conn = dbconn'ferre'
    local ret = escape(conn.header'datos')
    insert(ret, 2, remove(ret)) -- proveedor
    remove(ret) -- uidSAT
    insert(ret, 6, remove(ret)) -- rebaja
    remove(ret) -- costol
    ret = concat(ret, ', ')
    return format('%s [%s]', 'header', ret)
end

print( getHeader() )

