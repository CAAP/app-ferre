#! /usr/bin/env lua53

-- Import Section
--
local fd		= require'carlos.fold'

local asJSON		= require'carlos.json'.asJSON
local context		= require'lzmq'.context
local cache		= require'carlos.ferre'.cache
local dbconn		= require'carlos.ferre'.dbconn
local connexec		= require'carlos.ferre'.connexec
local decode		= require'carlos.ferre'.decode
local now		= require'carlos.ferre'.now
local aspath		= require'carlos.ferre'.aspath
local newTable    	= require'carlos.sqlite'.newTable
local dump		= require'carlos.files'.dump

local format	= require'string'.format
local concat 	= table.concat
local open	= io.open
local popen	= io.popen
local exec	= os.execute
local date	= os.date
local env	= os.getenv
local assert	= assert

local print	= print

local HOME	= require'carlos.ferre'.HOME
local APP	= require'carlos.ferre'.APP
local DEST	= HOME .. '/ventas/json/version.json'

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local DOWNSTREAM = 'ipc://downstream.ipc'
local UPSTREAM	 = 'ipc://upstream.ipc'

local SUBS	 = {'adjust', 'version', 'CACHE', 'KILL'} -- people
local CACHE	 = cache'Hi VERS'

--------------------------------
-- Local function definitions --
--------------------------------

-- find all updates that need to be sent to a specific peer & send them all
local function adjust(fruit, week, vers) exec(format('%s/dump-fruit.lua %s %s %d', APP, fruit, week, vers)) end

-- DUMP --
local function dumpPRICE() exec(format('%s/dump-price.lua', APP)) end

local function dumpPEOPLE() exec(format('%s/dump-people.lua', APP)) end

local function getVersion()
    dumpPRICE()

    local f = popen(format('%s/dump-vers.lua', APP))
    local v = f:read('l'):gsub('%s+%d$', '')
    f:close()

    dump(DEST, v)

    CACHE.store('vers', format('version %s', v))
    print(v)
    return v
end


---------------------------------
-- Program execution statement --
---------------------------------
--
-- -- -- -- -- --
--
-- Initialize server
--
local CTX = context()

local tasks = assert(CTX:socket'SUB')

assert(tasks:connect( DOWNSTREAM ))

fd.reduce(SUBS, function(s) assert(tasks:subscribe(s))  end)

print('Successfully connected to:', DOWNSTREAM)
print('And successfully subscribed to:', concat(SUBS, '\t'), '\n')
-- -- -- -- -- --
--
-- Connect to PUBlisher
local msgr = assert(CTX:socket'PUSH')

assert(msgr:connect( UPSTREAM ))

print('Successfully connected to:', UPSTREAM, '\n')
-- -- -- -- -- --
--
-- Compute latest version & Dump data
-- additionally sends SSE with latest version in case of UPGRADE!!!
-- could be solved otherwise XXX like in the admin-app
--
local vers = getVersion()
msgr:send_msg(format('version %s', vers))

dumpPEOPLE()

--
-- -- -- -- -- --
-- Run loop
--
while true do
print'+\n'
    local msg = tasks:recv_msg()
    local cmd = msg:match'%a+'
    if cmd == 'KILL' then
	if msg:match'%s(%a+)' == 'VERS' then
	    msgr:send_msg('Bye VERS')
	    break
	end
    elseif cmd == 'CACHE' then
	local fruit = msg:match'%s(%a+)'
	CACHE.sndkch( msgr, fruit )
	print('CACHE sent to', fruit, '\n')
    elseif cmd == 'version' then
	print'Version event ongoing!\n'
	msgr:send_msg(format('version %s', getVersion()))
    elseif cmd == 'adjust' then
	local cmd, o = decode(msg) -- o: fruit, week, vers
	adjust(o.fruit, o.week, o.vers)
	print'Adjust process successful!\n'
	msgr:send_msg(format('%s adjust %s.json', o.fruit, o.fruit))
    end
end


--[[
--]]
