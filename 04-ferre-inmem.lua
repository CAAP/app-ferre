#! /usr/bin/env lua53

-- Import Section
--
local reduce		= require'carlos.fold'.reduce
local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin

local tabs		= require'carlos.ferre.tabs'
local vers		= require'carlos.ferre.vers'

local concat 	= table.concat
local assert	= assert
local type	= type

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local STREAM = 'ipc://stream.ipc'

local UPSTREAM = 'ipc://upstream.ipc'

local TABS = { tabs=true, delete=true, msgs=true,
		pins=true, login=true, CACHE=true }

local VERS = { 	adjust=true, version=true, CACHE=true }

--------------------------------
-- Local function definitions --
--------------------------------
--

---------------------------------
-- Program execution statement --
---------------------------------
--
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'inmem' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM)

--
-- -- -- -- -- --
--
local msgr = assert(CTX:socket'PUSH')

assert( msgr:immediate( true ) )

assert( msgr:connect( UPSTREAM ) )

print('\nSuccessfully connected to:', UPSTREAM)
--
-- -- -- -- -- --
--

tasks:send_msg'OK'

--
--
-- Run loop
--

local function send( m ) return msgr:send_msg(m) end

while true do
print'+\n'
    pollin{tasks}
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    print(msg, '\n')

    if TABS[cmd] then
	local ret = tabs( msg )
	if type(ret) == 'table' then
	    reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK tabs!\n'
    end

    if VERS[cmd] then
	local ret = vers( msg )
	if type(ret) == 'table' then
	    reduce(ret, send)
	elseif ret ~= 'OK' then send( ret ) end
	print'OK vers!\n'
    end

end


