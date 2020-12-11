#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local slice	  = require'carlos.fold'.slice
local into	  = require'carlos.fold'.into

local rconnect	  = require'redis'.connect

local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

local posix	  = require'posix.signal'

local assert	  = assert
local concat	  = table.concat

local exit	  = os.exit
local print	  = print
local stdout	  = io.stdout
local popen	  = io.popen

local STREAM	  = os.getenv'STREAM_IPC'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local PRINTER	 = 'nc -N 192.168.3.21 9100'

local client	  = assert( rconnect('127.0.0.1', '6379') )
local QIDS	  = 'queue:uuids:'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function bixolon( uid )
    local k = QIDS..uid
    local data = client:lrange(k, 0, -1)

    local skt = popen(PRINTER, 'w') -- stdout -- 
    if #data > 8 then
	data = slice(4, data, into, {})
	reduce(data, function(v) skt:write(concat(v,'\n'), '\n') end)
    else
	skt:write( concat(data,'\n') )
    end
    skt:close()
end


---------------------------------
-- Program execution statement --
---------------------------------

local function shutdown()
    print('\nSignal received...\n')
    print('\nBye bye ...\n')
    exit(true, true)
end

posix.signal(posix.SIGTERM, shutdown)
posix.signal(posix.SIGINT, shutdown)

--
-- Initilize server(s)
--

local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:linger(0) )

assert( tasks:set_id'lpr' )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{tasks}

	local msg = tasks:recv_msg() -- receive(server)

	print(msg, '\n')

	bixolon( msg )

end