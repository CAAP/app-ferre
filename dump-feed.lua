#! /usr/bin/env lua53

local fd	= require'carlos.fold'

local dbconn	= require'carlos.ferre'.dbconn
local uid2week	= require'carlos.ferre'.uid2week
local asJSON	= require'json'.encode

local concat	= table.concat
local remove	= table.remove
local insert	= table.insert
local format	= string.format
local assert	= assert

local print	= print

local HOME	= require'carlos.ferre'.HOME

local msg	= arg[1]

_ENV =  nil

local cmd = msg:match'%a+'

local fruit = msg:match'fruit=(%a+)'

local uid   = msg:match'uid=([^!&]+)'

local week = uid2week( uid )

local conn = assert( dbconn( week ) )

local path = format('%s/caja/json/%s-feed.json', HOME, fruit)

local qry = cmd == 'uid' and format(QTKT, uid) or format(QUID, 'LIKE', uid..'%')

local clause = format(CLAUSE, 'LIKE', uid..'%')

if cmd == 'ledger' and conn.count( 'tickets', clause ) == 0 then return false end

dump(path, asJSON(fd.reduce(conn.query(qry), fd.map(toCents), fd.map(addName), fd.into, {})))
