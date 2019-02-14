-- Import Section
--
local stream  = require'carlos.zmq'.stream
local socket  = require'carlos.zmq'.socket
local format  = require'string'.format
local sse     = require'carlos.html'.response
local pollin  = require'lzmq'.pollin
local context = require'lzmq'.context
local fd      = require'carlos.fold'
local asJSON  = require'carlos.json'.asJSON
local file_exists = require'carlos.bsd'.file_exists
local sql 	  = require'carlos.sqlite'
local env	  = os.getenv

local rand    = math.random
local concat = table.concat
local assert = assert
local print = print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local ENDPOINT  = 'tcp://*:5030'
local UPDATES   = 'ipc://updates.ipc'
local PEERS     = {}
local HELLO     = sse{content='stream'}
local TIMEOUT   = 5000 -- 5 secs
local SUBS	= {'vers', 'ups'}
local PRECIOS   = env'HOME' .. '/db/ferre.db'

local CTX 	= context()

--------------------------------
-- Local function definitions --
--------------------------------
--
local function sse( event, data ) return format('event: %s\ndata: %s\n\n', event, data) end

local function upSSE( port )
    local peer = 'tcp://*:'..port
    local srv = stream( peer, CTX )
    print('Successfully bound to:', peer, '\n')

    local id, msg = srv.receive()
    id, msg = srv.receive() -- receive salutation
    srv.send(id, HELLO)

    fd.reduce(PRECIOS, function(x) srv.send(id, sse('update', asJSON(x))) end)

    srv.send(id, '')
end

local function handshake(server)
    local id, msg = server.receive()
    local peer = PEERS[id]
    if peer then PEERS[id] = nil; return false; else PEERS[id] = true; end
    id, msg = server.receive() -- receive salutation
    if #msg > 0 then
	if msg:match'GET / ' then server.send(id, HELLO)
	elseif msg:match'GET /upgrade' then upSSE( rand(5051, 6051) ) end
    end
    return id
end

local function broadcast(sub, server)
    local msg = sub.receive():match'%a+ ([^|]+)'
    print(msg)
    fd.reduce(fd.keys(PEERS), function(_,id) server.send(id, msg) end)
end

local function precios()
    local path = PRECIOS
    assert(file_exists(path))
    local conn = assert(sql.connect(path))
    local qry = 'SELECT * FROM precios WHERE desc NOT LIKE "VV%"'

    PRECIOS = fd.reduce(conn.query(qry), fd.into, {})
end

---------------------------------
-- Program execution statement --
---------------------------------
--
local server = stream(ENDPOINT, CTX)

print('Successfully bound to:', ENDPOINT, '\n')
-- -- -- -- -- --
--
local sub = socket('SUB', CTX)

assert(sub.connect(UPDATES))
fd.reduce(SUBS, function(x) assert(sub.subscribe(x)) end)

print(format('Successfully connected to %q and subscribed to %s\n', UPDATES, concat(SUBS,', ')))
-- -- -- -- -- --
--
precios()
print'Successfully loaded the "ferre.db" DB ...\n'
-- -- -- -- -- --
--
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

