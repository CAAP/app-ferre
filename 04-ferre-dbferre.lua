#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local into		= require'carlos.sqlite'.into
local split		= require'carlos.string'.split
local context		= require'lzmq'.context
local pollin		= require'lzmq'.pollin
local keypair		= require'lzmq'.keypair
local dbconn		= require'carlos.ferre'.dbconn
local now		= require'carlos.ferre'.now
local asnum		= require'carlos.ferre'.asnum
local asJSON		= require'json'.encode

local format	= string.format
local tointeger = math.tointeger
local concat 	= table.concat
local date	= os.date
local tonumber  = tonumber
local tostring	= tostring
local assert	= assert
local pcall     = pcall

local pairs	= pairs

local print	= print

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local HOY	 = date('%d-%b-%y', now())

local STREAM = 'ipc://stream.ipc'

local LEDGER	 = 'tcp://149.248.21.161:5610' -- 'vultr'
local SRVK	 = "*dOG4ev0i<[2H(*GJC2e@6f.cC].$on)OZn{5q%3"

local DIRTY	 = {clave=true, tbname=true, fruit=true}
local TOLL	 = {costo=true, impuesto=true, descuento=true, rebaja=true}
local ISSTR	 = {desc=true, fecha=true, obs=true, proveedor=true, gps=true, u1=true, u2=true, u3=true, uidPROV=true}
local PRCS	 = {prc1=true, prc2=true, prc3=true}

local UPQ	 = 'UPDATE %q SET %s %s'
local COSTOL 	 = 'costol = costo*(100+impuesto)*(100-descuento)*(1-rebaja/100.0)'

--------------------------------
-- Local function definitions --
--------------------------------
--
local function smart(v, k) return ISSTR[k] and format("'%s'", tostring(v):upper()) or (tointeger(v) or tonumber(v) or 0) end

local function reformat(v, k)
    local vv = smart(v, k)
    return format('%s = %s', k, vv)
end

local function reformat2(clave, n)
    clave = tointeger(clave) or format('%q', clave) -- "'%s'"
    return function(v, k)
	local vv = smart(v, k)
	local ret = {n, clave, k, vv}
	n = n + 1
	return ret
    end
end

local function found(a, b) return fd.first(fd.keys(a), function(_,k) return b[k] end) end

local function sanitize(b) return function(_,k) return not(b[k]) end end

local function up_faltantes()
--    Otra BASE de DATOS XXX
--    w.faltantes = 0
--    qry = format('UPDATE faltantes SET faltante = 0 %s', clause)
--    assert(conn.exec( qry ), qry)
end

local function up_costos(w, a) -- conn
    for k in pairs(TOLL) do w[k] = nil end
    fd.reduce(fd.keys(a), fd.filter(function(_,k) return k:match'^precio' or k:match'^costo' end), fd.merge, w)
    return w
end

local function up_precios(conn, w, clause)
    local qry = format('SELECT * FROM precios %s LIMIT 1', clause)
    local a = fd.first(conn.query(qry), function(x) return x end)

    fd.reduce(fd.keys(w), fd.filter(function(_,k) return k:match'prc' end), fd.map(function(_,k) return k:gsub('prc', 'precio') end), fd.rejig(function(k) return a[k], k end), fd.merge, w)

    for k in pairs(PRCS) do w[k] = nil end

    return a, w
end

local function addUpdate(msg, conn)
    local w = {}
    for k,v in msg:gmatch'([%a%d]+)=([^&]+)' do w[k] = asnum(v) end

    local clave  = w.clave
    local tbname = w.tbname
    local clause = format('WHERE clave LIKE %q', clave)
    local toll = found(w, TOLL)

    if w.fecha or toll then w.fecha = HOY end -- add 'fecha' update!!! XXX
--    if toll then w.fecha = HOY end

    local u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat), fd.into, {})
    if #u == 0 then return false end -- safeguard
    local qry = format(UPQ, 'datos', concat(u, ', '), clause)

---[[
--    print( qry )
    pcall(conn.exec( qry ))
    if toll then
	qry = format(UPQ, 'datos', COSTOL, clause)
	pcall(conn.exec( qry ))
    end

    if found(w, PRCS) or toll then
	local a = up_precios(conn, w, clause)
	if toll then up_costos(w, a) end
    end

    return w

    -- XXX move to dbweek
    u = conn2.count'updates' + 1

    fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat2(clave, u)), into'updates', conn2)

--    u = fd.reduce(fd.keys(w), fd.filter(sanitize(DIRTY)), fd.map(reformat2(clave)), fd.into, {})
--    print( concat(u,'\n') )
 --   for _,q in ipairs(u) do assert(conn2.exec( q )) end

--    exec(format('%s/dump-price.lua', APP))

    return true
--]]
end

---------------------------------
-- Program execution statement --
---------------------------------
--
-- Database connection(s)
--
local PRECIOS = assert( dbconn'ferre' )

print("ferre DBs was successfully open\n")
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'DEALER')

assert( tasks:immediate(true) )

assert( tasks:set_id'ferredb' )

assert(tasks:connect( STREAM ))

print('\nSuccessfully connected to:', STREAM)
--
--[[ -- -- -- -- --
--
local www = assert(CTX:socket'REQ')

assert( www:set_id'FA-BJ-01' )

assert( keypair():client(www, SRVK) )

assert( www:connect( LEDGER ) )

print('\nSuccessfully connected to:', LEDGER, '\n')
--
--]] -- -- -- -- --
--
-- -- -- -- -- --
--
-- Run loop
--

while true do
print'+\n'
    pollin{tasks}
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    print(msg, '\n')

    if cmd == 'update' then
	local fruit = msg:match'fruit=(%a+)'
	local ret = addUpdate(msg, PRECIOS)
	tasks:send_msgs{'weekdb', asJSON(ret)}

--	www:send_msg( msg ) -- WWW


    elseif cmd == 'faltante' then
	print( msg )

    end
end


