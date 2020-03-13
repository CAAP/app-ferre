#! /usr/bin/env lua53

-- Import Section
--

local reduce	  = require'carlos.fold'.reduce
local into	  = require'carlos.fold'.into
local map	  = require'carlos.fold'.map
local urldecode   = require'carlos.ferre'.urldecode
local newUID	  = require'carlos.ferre'.newUID
local asnum	  = require'carlos.ferre'.asnum
local asJSON	  = require'json'.encode
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local assert	  = assert
local concat	  = table.concat
local remove	  = table.remove

local print	  = print

--local WEEK = require'carlos.ferre'.asweek( require'carlos.ferre'.now() )

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM  = 'ipc://downstream.ipc' --  
local UPSTREAM    = 'ipc://upstream.ipc'
local STREAM	  = 'ipc://stream.ipc'

local MULTI	 = {tabs=true, ticket=true, presupuesto=true}

--------------------------------
-- Local function definitions --
--------------------------------
--

local function process(uid, tag)
    return function(q)
	local o = {uid=uid, tag=tag}
	for k,v in q:gmatch'([%a%d]+)|([^|]+)' do o[k] = asnum(v) end
	o.lbl = 'u' .. o.precio:match'%d$'
	o.rea = (100-o.rea)/100.0
	return asJSON(o)
    end
end

--[[
	local b = fd.first(conn2.query(format(QRY, o.clave)), function(x) return x end)
	fd.reduce(fd.keys(o), fd.merge, b)
	b.precio = b[o.precio]; b.unidad = b[o.lbl];
	b.prc = o.precio; b.unitario = o.rea < 1 and round(b.precio*o.rea, 2) or b.precio
	return fd.reduce(INDEX, fd.map(function(k) return b[k] or '' end), fd.into, {})
--]]

local function asTicket(cmd, uid, msg)
    remove(msg, 1)
    return reduce(msg, map(urldecode), map(process(uid, cmd)), into, {cmd})
end

local function receive(skt, a)
    return reduce(function() return skt:recv_msgs(true) end, into, a)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
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

--[[ -- -- -- -- --
--

local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate(true) ) -- queue outgoing to completed connections only

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM, '\n')

--
--]] -- -- -- -- --
--

tasks:send_msg'OK'

while true do
print'+\n'

    pollin{server}

	    local msg, more = server:recv_msg()
	    local cmd = msg:match'%a+'
	    local pid = msg:match'pid=([%d%a]+)'

	    if more then
		msg = receive(server, {msg})
		print(concat(msg, '&'), '\n')
	    else
		print(msg, '\n')
	    end

	    ----------------------
	    -- divide & conquer --
	    ----------------------
	    if cmd == 'bixolon' then

	    else
		if more then
		-- ticket, presupuesto & tabs are multi-part msgs
		    if MULTI[cmd] then
	 		local uid = newUID()..pid
			msg = asTicket(cmd, uid, msg)
		    end

		    tasks:send_msgs( msg )

		else tasks:send_msg( msg ) end

	    end
end
