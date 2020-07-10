#! /usr/bin/env lua53

-- Import Section
--

local mgr	= require'lmg'
local context	= require'lzmq'.context

local posix	= require'posix.signal'
local exit	= os.exit
local env	= os.getenv
local assert	= assert
local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT	 = env'HTTP_PORT'
local STREAM	 = env'STREAM_IPC'
local events	 = mgr.events

--------------------------------
-- Local function definitions --
--------------------------------
--

local function shutdown()
    print('\nShutting down server at port', ENDPOINT)
    print'\nBye bye...\n'
    exit(true, true)
end



---------------------------------
-- Program execution statement --
---------------------------------
--
--

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
--
-- Initilize server(s)

local CTX = assert( context() )

local msgr = assert( CTX:socket'DEALER' )

assert( msgr:immediate(true) )

assert( msgr:linger(0) )

assert( msgr:set_id'ppp' )

assert( msgr:connect( STREAM ) )

print('\nSuccessfully connected to', STREAM, '\n')

msgr:send_msg'OK'

-- -- -- -- -- --
--

local function frontend(c, ev, ...)
    if ev == events.REQUEST then
	local _,uri,query,_ = ...
	print('\nAPP\t', ...)
	c:reply(200, 'OK', 'Content-Type: text/plain', true)
	msgr:send_msgs{uri, query}
    end
end

local function stream(c, ev, ...)
    if ev == events.RECV then
	local msg = ...
	print('\nstream\t', msg, '\n')
    end
end

local server = assert( mgr.bind(ENDPOINT, frontend, 'http') )

print('\nSuccessfully bound to port', ENDPOINT, '\n')

local stream = assert( mgr.bind('4990', stream) )

print('\nSuccessfully bound to port', 4990, '\n')

-- -- -- -- -- --
--

while true do mgr.poll(120000) end

