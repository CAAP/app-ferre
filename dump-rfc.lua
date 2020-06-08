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
    local conn = dbconn'personas'
    local ret = escape(conn.header'clientes')
    remove(ret, 1) -- rfc
    remove(ret) -- fapi
    ret = concat(ret, ', ')
    return format('%s [%s]', 'taxes', ret)
end

print( getHeader() )

