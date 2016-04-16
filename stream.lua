local socket = require("socket")

local host = "*"
local port = 8080
local server = assert(socket.bind(host, port))
server:settimeout(1) -- make sure we don't block in accept

io.write("Servers bound\n")

-- simple set implementation
-- the select function doesn't care about what is passed to it as long as
-- it behaves like a table
-- creates a new set data structure
local function newset()
    local reverse = {}
    local set = {}
    return setmetatable(set, {__index = {
        insert = function(set, value)
            if not reverse[value] then
                table.insert(set, value)
                reverse[value] = #set
            end
        end,
        remove = function(set, value)
            local index = reverse[value]
            if index then
                reverse[value] = nil
                local top = table.remove(set)
                if top ~= value then
                    reverse[top] = index
                    set[index] = top
                end
            end
        end
    }})
end

local function getHeader()
    'GET /XXX HTTP/1.1'
    'Host:'
    'Accept:'
    'Last-Event-ID:'
end
-- Authorization: BASIC usr:pwd
-- Host: host:port
-- 500 Internal Server Error

local function streaming()
    local header = {'HTTP/1.1 200 OK',
		'Content-Type: text/event-stream',
		'Connection: keep-alive',
		'Cache-Control: no-cache',
		'Transfer-Encoding: chunked',
		'Allow: GET',
		''}
end

local set = newset()

while 1 do
            local new = server:accept()
            if new then
                new:settimeout(1)
		io.write("New client.\n")
		local line, error = new:receive()
		if not error then
		    io.write("Receiving: ", line, "\n")
		    header[#header+1] = 'OK'
		    header[#header+1] = '\n'
		    new:send( table.concat(header, '\n') )
		end
		new:close()
            end
end

