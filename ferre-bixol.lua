#! /usr/bin/env lua53

-- Import Section
--
local fd	= require'carlos.fold'

local context	= require'lzmq'.context
local pollin	= require'lzmq'.pollin
local lpr	= require'carlos.ticket'.bixolon
local ticket	= require'carlos.ticket'.ticket
local asweek	= require'carlos.ferre'.asweek
local dbconn	= require'carlos.ferre'.dbconn

local assert	= assert
local tostring	= tostring
local concat	= table.concat
local format	= string.format

local print	= print

local asJSON = require'carlos.json'.asJSON

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc'
local LPR	 = 'ipc://lpr.ipc'
local TBNAME	 = 'tickets'

local SUBS	 = {'bixolon', 'KILL'}
local QRY	 = 'SELECT desc, clave, qty, rea, unitario, ROUND(totalCents/100.0) subTotal FROM tickets WHERE uid LIKE %q'
local QHEAD	 = 'SELECT uid, tag, ROUND(SUM(totalCents)/100.0,2) total from tickets WHERE uid LIKE %q GROUP BY uid'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function bixolon(msg)
    local uid = msg:match'%s([^!]+)'
    local week = asweek(uid)
    local conn = dbconn(week)

    local ret = fd.first(conn.query(format(QHEAD, uid)), function(x) return x end)
    ret.total = tostring(ret.total)
 print(asJSON(ret))
    local data = fd.reduce(conn.query(format(QRY, uid)), fd.into, {})
    ret.datos = data

print( ticket(ret) )

    return uid
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initialize server
local CTX = context()

local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

fd.reduce(SUBS, function(s) assert(tasks:subscribe(s))  end)

print('Successfully connected to:', DOWNSTREAM)
print('And successfully subscribed to:', concat(SUBS, '\t'), '\n')
-- -- -- -- -- --
--
local tickets = assert(CTX:socket'PULL')

assert(tickets:bind( LPR ))

print('Successfully bound to:', LPR)
-- -- -- -- -- --
--

-- Run loop
--
while true do
print'+\n'
    pollin{tasks, tickets}
	if tasks:events() == 'POLLIN' then
	    local msg = tasks:recv_msg()
	    local cmd = msg:match'%a+'
	    if cmd == 'KILL' then
		if msg:match'%s(%a+)' == 'BIXOL' then
		    print'Bye BIXOL'
		    break
		end
	    end
	    if cmd == 'bixolon' then
		print('Printing ticket with uid:', bixolon(msg), '\n')
	    end
	end
	if tickets:events() == 'POLLIN' then
	    local msg = tickets:recv_msg()
	    local cmd = msg:match'%a+'
	    if cmd == 'bixolon' then
		print('Printing ticket with uid:', bixolon(msg), '\n')
	    end
	end
end

