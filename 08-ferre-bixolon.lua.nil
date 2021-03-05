#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local slice	  = require'carlos.fold'.slice
local into	  = require'carlos.fold'.into
local deserialize = require'carlos.ferre'.deserialize

local rconnect	  = require'redis'.connect

local socket	  = require'lzmq'.socket
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
local QIDS	  = 'queue:uuids'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function bixolon( w )
    local uid = w.uid
    assert(uid, "error: uid cannot be nil")
    local data = deserialize(client:hget(QIDS, uid))
    client:hdel(QIDS, uid)
    local k = 1
    if w.tag == 'facturar' then k = 2 end
    for j=1,k do
	local skt = stdout -- popen(PRINTER, 'w') -- 
	skt:write( concat(data,'\n') )
	skt:close()
    end
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

local tasks = assert(socket'DEALER')

assert( tasks:opt('immediate', true) )

assert( tasks:opt('linger', 0) )

assert( tasks:opt('id', 'lpr') )

assert( tasks:connect( STREAM ) )

print('\nSuccessfully connected to:', STREAM, '\n')

tasks:send_msg'OK'

--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{tasks}

    local events = tasks:opt'events'

    if events.pollin then

	-- two messages received: cmd & [binser] Lua Object --
	local s = tasks:recv_msg()

	print(s, '\n')

	local w = deserialize(s)

	bixolon( w )

    end

end
