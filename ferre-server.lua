-- Import Section
--
local stream  = require'carlos.zmq'.stream
local socket  = require'carlos.zmq'.socket
local format  = require'string'.format
local sse     = require'carlos.html'.response
local pollin  = require'lzmq'.pollin
local context = require'lzmq'.context
local fd      = require'carlos.fold'

local concat = table.concat
local assert = assert
local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT  = 'tcp://*:5050'
local TICKETS   = 'ipc://tickets.ipc'
local PEERS     = {}
local HELLO     = sse{content='stream'}
local TIMEOUT   = 5000 -- 5 secs
local SUBS	= {'vers', 'tkts'}

--------------------------------
-- Local function definitions --
--------------------------------
--
local function handshake(server)
    local id, msg = server.receive()
    local peer = PEERS[id]
    if peer then PEERS[id] = nil; return false; else PEERS[id] = true; end
    id, msg = server.receive() -- receive salutation
    if #msg > 0 then
	print( concat(msg, '\n') )
	server.send(id, HELLO) -- give salutation back
    end
    return id
end

local function broadcast(sub, server)
    local msg = sub.receive():gmatch'%a+ ([^|]+)'
    print(msg)
    fd.reduce(fd.keys(PEERS), function(_,id) server.send(id, msg) end)
end

---------------------------------
-- Program execution statement --
---------------------------------
--
local ctx = context()

local server = stream(ENDPOINT, ctx)

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
local sub = socket('SUB', ctx)

assert(sub.connect(TICKETS))
fd.reduce(SUBS, function(x) assert(sub.subscribe(x)) end)

print(format('Successfully connected to %q and subscribed to %s\n', TICKETS, concat(SUBS,', ')))
-- -- -- -- -- --
local poll = pollin{server.socket(), sub.socket()}

while true do
    local j = poll(TIMEOUT)
    print(j, '\n\n')
    if j == 1 then
	if not handshake(server) then print'Bye bye ...\n' end
    elseif j == 2 then
	broadcast(sub, server)
    end
end

