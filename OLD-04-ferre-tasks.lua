#! /usr/bin/env lua53

-- Import Section
--

local fd	  = require'carlos.fold'

local urldecode   = require'carlos.ferre'.urldecode
local newUID	  = require'carlos.ferre'.newUID
local asnum	  = require'carlos.ferre'.asnum
local asJSON	  = require'json'.encode
local fromJSON	  = require'json'.decode
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local format	  = string.format
local concat	  = table.concat
local remove	  = table.remove
local tointeger	  = math.tointeger

local assert	  = assert
local print	  = print
local pcall	  = pcall
local tostring	  = tostring
local tonumber	  = tonumber

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM  = 'ipc://downstream.ipc' --  
local UPSTREAM    = 'ipc://upstream.ipc'

local ISTKT 	  = {ticket=true, presupuesto=true} -- tabs=true
--------------------------------
-- Local function definitions --
--------------------------------
--

local function process(uid, persona, tag)
    return function(q)
	local o = {uid=uid, tag=tag, nombre=persona}
	for k,v in q:gmatch'([%a%d]+)|([^|]+)' do o[k] = asnum(v) end
	local lbl = 'u' .. o.precio:match'%d$'
	local rea = (100-o.rea)/100.0

	local b = fd.first(PRECIOS.query(format(QRY, o.clave)), function(x) return x end)
	fd.reduce(fd.keys(o), fd.merge, b)
	b.precio = b[o.precio]; b.unidad = b[lbl];
	b.prc = o.precio; b.unitario = b.rea > 1 and round(b.precio*rea, 2) or b.precio

	return asJSON(b)
    end
end

local function asTicket(cmd, uid, persona, msg)
    remove(msg, 1)
    return fd.reduce(msg, fd.map(urldecode), fd.map(process(uid, persona, cmd)), fd.into, {cmd})
end

local function receive(skt, a)
    return fd.reduce(function() return skt:recv_msgs(true) end, fd.into, a)
end

---------------------------------
-- Program execution statement --
---------------------------------
--

-- -- -- -- -- --
-- Initilize server(s)
local CTX = context()


local server = assert(CTX:socket'PULL')

assert(server:connect( DOWNSTREAM ))

print('Successfully connected to:', DOWNSTREAM, '\n')

-- -- -- -- -- --
--

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'TASKS01' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

-- -- -- -- -- --
--

tasks:send_msg'OK'

while true do
print'+\n'

    pollin{server}

	    local msg, more = server:recv_msg()
	    local cmd = msg:match'%a+'
	    local pid = asnum( msg:match'pid=([%d%a]+)' )

	    if more then
		msg = receive(server, {msg})
		print(concat(msg, '&'), '\n')
	    else
		print(msg, '\n')
	    end

	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if more then

		if ISTKT[cmd] then
	 	    local uid = newUID()..pid
		    msg = asTicket(cmd, uid, PID[pid] or 'NaP', msg)
		end

		tasks:send_msgs( msg )

	    else tasks:send_msg( msg )

	    end

end

