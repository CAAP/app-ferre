#!/usr/local/bin/lua

local env = os.getenv
local rand = math.random
local format = string.format
local date = os.date

local fs = require'carlos.files'

local lng = math.tointeger(env'CONTENT_LENGTH')
local uri = env'QUERY_STRING'

if env('REQUEST_METHOD'):match'POST' and lng > 0 then
    local s = io.read(lng)
    assert( fs.dump(format('posts/T%sR%03d.txt', date('%X'):gsub(':',''), rand(100)), s) )
end

print'Content-Type: text/plain; charset=utf-8\r\n\r\nOK\n'
