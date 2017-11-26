local sql = require'carlos.sqlite'
local fd = require'carlos.fold'
local ex = require'ferre.extras'

local MM = {}

local hoy = os.date('%d-%b-%y', ex.now())

local ups = {week=week, vers=0, store='VERS', prevs=-1}

local isstr = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true}

local function reformat(v, k)
    local vv = isstr[k] and string.format("'%s'", v:upper()) or (math.tointeger(v) or tonumber(v) or 0)
    return k .. ' = ' .. vv
end

local function precios(conn, w, clause, f)
    local qry = string.format('SELECT * FROM precios %s', clause)
    local ret = fd.first( conn.query(qry), function(x) return x end )
    fd.reduce( fd.keys(precios(clause)), fd.filter(f), fd.merge, w )
end

local function up_costos(conn, w, clause)
    local costol = 'UPDATE datos SET costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100), fecha = %q %s'

    w.costo = nil; w.impuesto = nil; w.descuento = nil; w.fecha = hoy;

    local qry = string.format(costol, w.fecha, clause)
    assert( conn.exec( qry ), 'Error executing: ' .. qry )
    w.faltante = 0
    qry = string.format('UPDATE faltantes SET faltante = 0 %s', clause)
    assert(conn.exec(qry), 'Error executing: ' .. qry)

    -- VIEW precios is necessary to produce precio1, precio2, etc
    precios( conn, w, clause, function(_,k) return k:match'^precio' end )
	-- in order to update costo in admin.html
    w.costol = fd.first( conn.query(string.format('SELECT costol FROM datos %s', clause)), function(x) return x end ).costol
end

local function up_precios(w, clause)
    local ps = fd.reduce( fd.keys(w), fd.filter(function(_,k) return k:match'^prc' end), fd.rejig(function(_,k) return true,k:gsub('prc','precio') end), fd.merge, {} )

    w.prc1 = nil; w.prc2 = nil; w.prc3 = nil;

    precios( w, clause, function(_,k) return ps[k] end )
end

function MM.add( conn, w )
	local clave = w.clave
	local tbname = w.tbname
	local clause = string.format('WHERE clave LIKE %q', clave)

	w.id_tag = nil; w.args = nil; w.clave = nil; w.tbname = nil; -- SANITIZE

	local ret = fd.reduce( fd.keys(w), fd.map( reformat ), fd.into, {} )
	local qry = string.format('UPDATE %q SET %s %s', tbname, table.concat(ret, ', '), clause)
	assert( conn.exec( qry ), qry )

	if w.costo or w.impuesto or w.descuento or w.rebaja then up_costos(conn, w, clause) end

	if w.prc1 or w.prc2 or w.prc3 then up_precios(w, clause) end

	ret = {VERS=ups}
	ups.week = week
	ups.prev = ups.vers

	local function events(k, v)
	    local store = 'PRICE' -- stores[k] or 'PRICE'
	    if not ret[store] then ret[store] = {clave=clave, store=store} end
	    ret[store][k] = v
	end

	fd.reduce( fd.keys(w), fd.map(function(v,k) events(k, v); return {'', clave, k, v} end), sql.into'updates', conn )

	ups.vers = conn.count'updates'

	return ret
end

function MM.init(conn)
    local schema = 'vers INTEGER PRIMARY KEY, clave, campo, valor'
    assert( conn.exec( string.format(sql.newTable, 'updates', schema) ) )
    
    ex.version( ups )
    print('Version: ', ups.vers, 'Week: ', ups.week, '\n')
end

function MM.sse() return ups end -- prev=ups.vers

return MM
