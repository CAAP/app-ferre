
-- Import Section
local fd	= require'carlos.fold'

local asJSON	= require'carlos.json'.asJSON
local newUID	= require'carlos.ferre'.newUID
local uid2week	= require'carlos.ferre'.uid2week
local cache	= require'carlos.ferre'.cache
local pollin	= require'lzmq'.pollin
local context	= require'lzmq'.context

local format	= string.format
local popen	= io.popen
local concat	= table.concat
local assert	= assert

local print	= print

local APP	= require'carlos.ferre'.APP

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local SUBS	 = {'feed', 'ledger', 'uid', 'query', 'CACHE', 'KILL'} -- 'factura',  'bixolon',

local CACHE	 = cache'Hi CMDS'

local CAJA, TAXES

--------------------------------
-- Local function definitions --
--------------------------------

local function getRFC()
    local f = popen(format('%s/dump-rfc.lua', APP))
    local v = f:read'l'
    f:close()
    return v
end

local function queryDB(msg)
    local fruit = msg:match'fruit=(%a+)'
    msg = msg:match('%a+%s([^!]+)'):gsub('&', '!')
    print('Querying database:', msg, '\n')
    local f = assert( popen(format('%s/dump-query.lua %s', APP, msg)) )
    local v = f:read'l'
    f:close()
    return format('%s query %s', fruit, v)
end

--------------------------------
--------------------------------

-- find all updates that need to be sent to a specific peer & send them all
local function adjust(fruit, week, vers) exec(format('%s/dump-fruit.lua %s %s %d', APP, fruit, week, vers)) end

-- DUMP --
local function dumpPRICE() exec(format('%s/dump-price.lua', APP)) end

local function getVersion()
    dumpPRICE()

    local f = popen(format('%s/dump-vers.lua', APP))
    local v = f:read('l'):gsub('%s+%d$', '')
    f:close()

    dump(DEST, v) -- XXX really need this???

    CACHE.store('vers', format('version %s', v))
    print(v)
    return v
end

---------------------------------
-- 	Dump header to CACHE   --
---------------------------------

CACHE.store('RFC', getRFC())

---------------------------------
--
---------------------------------

local function switch( msg, msgr )

    local cmd = msg:match'%a+'
    if cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')

    elseif cmd == 'query' then
	local msg = queryDB( msg )
	msgr:send_msg( msg )
	print('Query result:', msg, '\n')

    elseif cmd == 'version' then
	print'Version event ongoing!\n'
	msgr:send_msg(format('version %s', getVersion()))

    elseif cmd == 'adjust' then
	local cmd, o = decode(msg) -- o: fruit, week, vers
	adjust(o.fruit, o.week, o.vers)
	print'Adjust process successful!\n'
	msgr:send_msg(format('%s adjust %s.json', o.fruit, o.fruit))



    elseif cmd == 'feed' then
	local fruit = msg:match'%s(%a+)' -- secs = %s(%d+)$
	local t = date('%FT%T', now()):sub(1, 10)
	local qry = format(QUID, '>', t)
	local cls = format(CLAUSE, '>', t)
	if dumpFEED(WEEK, feedPath(fruit), qry, cls) then
	    print'Updates stored and dumped\n'
	    msgr:send_msg( format('%s feed %s-feed.json', fruit, fruit) )
	end

-- ledger & uid

    elseif cmd == 'ledger' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local week  = msg:match'week=([^!&]+)'
	local qry   = format(QUID, 'LIKE', uid..'%')
	local cls   = format(CLAUSE, 'LIKE', uid..'%')
	if dumpFEED(which(week), feedPath(fruit), qry, cls) then
	    print'Historic data stored and dumped\n'
	    msgr:send_msg( format('%s ledger %s-feed.json', fruit, fruit) )
	end

    elseif cmd == 'uid' then
	local fruit = msg:match'fruit=(%a+)'
	local uid   = msg:match'uid=([^!&]+)'
	local week  = msg:match'week=([^!&]+)'
	local qry   = format(QTKT, uid)
	dumpFEED(which(week), feedPath(fruit), qry, false)
	print'Data for UID stored and dumped\n'
	msgr:send_msg( format('%s uid %s-feed.json', fruit, fruit) )
    end
end

