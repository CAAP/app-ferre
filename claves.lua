#! /usr/local/bin/lua53

local sql = require'carlos.sqlite'
local fd = require'carlos.fold'
local tb = require'carlos.tables'

local PATH = 'db/ferre.db'

local conn = sql.connect(PATH)
local QRY = 'SELECT clave FROM datos'

local function isnotint(x) return not(math.tointeger(x)) end

local keys = fd.reduce(conn.query(QRY), fd.map(function(o) return o.clave end), fd.filter(isnotint), fd.rejig(function(x) return true,x end), fd.merge, {})

local letters = {'A', 'B', 'E', 'H', 'K', 'M', 'N', 'R', 'W', 'T'}

local ret = {}
for i=11,990 do
    for _,l in ipairs(letters) do
	local k = string.format('%s%03d', l, i)
	if not(keys[k]) then ret[#ret+1] = k end
    end
end

print('count: ', #ret)

tb.shuffle(ret)

--print(table.concat(ret, '\n'))

for _,k in ipairs(ret) do
    local cmd = string.format('INSERT INTO datos (clave) VALUES (%q)', k)
    assert(conn.exec(cmd), cmd)
end

