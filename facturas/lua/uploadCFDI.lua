#!/usr/local/bin/lua

local env = os.getenv
local format = string.format
local dump = require'carlos.files'.dump
local tointeger = math.tointeger
local read = io.read
local exists = require'carlos.bsd'.file_exists
local assert = assert
local print = print

-- No more external access after this point
_ENV = nil

-- Local variables for module-only access (private)
local lng = tointeger(env'CONTENT_LENGTH')

-- Local function for module-only access

---------------------------------
--  Script, Running, Execution --
---------------------------------
if env('REQUEST_METHOD'):match'POST' and lng > 0 then
    local s = read(lng)
    local path = format('cfdi/%s.xml', s:match'UUID="([^"]+)"')
    if not(exists(path)) then assert( dump(path, s) ) end
end

print'Content-Type: text/plain; charset=utf-8\r\n\r\nOK\n'
