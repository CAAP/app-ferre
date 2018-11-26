local sql = require'carlos.sqlite'
local fd = require'carlos.fold'
local ex = require'ferre.extras'
local hd = require'ferre.header'
local precio = require'ferre.precio'

local MM = {}

local today = os.date('%F', ex.now())

local tbname = 'tickets'

local clause = string.format("WHERE uid LIKE '%s%%'", today)

local query = "SELECT uid, SUM(qty) count, SUM(totalCents) totalCents, id_tag FROM %q WHERE uid LIKE '%s%%' GROUP BY uid||id_tag" -- uid(date+pid)+id_tag reflects changes in TICKET like ticket->venta

local nombres, tags

local function map( f )
    return fd.reduce(f, fd.rejig(function(a) return a.nombre,a.id end), fd.merge, {})
end

local function printme(conn, w)
    local uid = w.uid
    local y,m,d = uid:match'^(%d+)-(%d+)-(%d+)'

    local fields = hd.args{clave='clave',precio='precio',qty='qty',rea='rea',totalCents='totalCents'}

    -- FETCH -- in fn 'precio'
    -- No hashmap of clave,record; I need to add hashid; should I keep also a hashmap of clave|hashid,record? XXX
    local p = nombres[tonumber(uid:match'(%d+)$')] or 'NaP'
    local tag = tags[w.id_tag] or w.id_tag

    local ret = {uid=uid, person=p, tag=tag}
    ret.datos = fd.reduce( w.args, fd.map(fields), fd.map(precio(conn)), fd.into, {} ) -- fn 'precio' XXX conn
    ret.total = string.format('%.2f', w.totalCents/100)

    return ret
end


function MM.init( conn )
    local schema = 'uid, id_tag, clave, precio, qty INTEGER, rea INTEGER, totalCents INTEGER'
    assert( conn.exec( string.format(sql.newTable, tbname, schema) ) )

    nombres = map(conn.query'SELECT * FROM empleados')
    tags = map(conn.query'SELECT * FROM tags')
end

function MM.add( conn, w )
   local keys = { uid=1, id_tag=2, clave=3, precio=4, qty=5, rea=6, totalCents=7 }
   local uid = os.date('%FT%TP', ex.now()) .. w.pid -- date+PersonID

    fd.reduce( w.args, fd.map( hd.args(keys, uid, w.id_tag) ), sql.into( tbname ), conn ) -- ids( uid, w.id_tag ),
    local a = fd.first( conn.query(string.format(query, tbname, uid)), function(x) return x end )
    w.uid = uid; w.totalCents = a.totalCents; w.count = a.count
    return printme(conn, w)
end

--- XXX fd.split for count > 50
function MM.sse( conn )
    if conn.count( tbname, clause ) == 0 then return false,':empty\n\n'
    else return true,conn.query(string.format(query, tbname, today))
end

return MM

