local fd = require'carlos.fold'
local sql = require'carlos.sqlite'

local conn = sql.connect'ferre.db'

local function quot(x) return math.tointeger(x) or tonumber(x) or '"'..x..'"' end

local function ntilde(a) a.desc = a.desc:gsub('&Ntilde;', 'Ñ'); return a end

local function get(clave)
    local QRY = string.format('SELECT * FROM datos WHERE clave like %q', clave)
    local item = fd.first( conn.query(QRY) ) -- what happens when not found???
end


