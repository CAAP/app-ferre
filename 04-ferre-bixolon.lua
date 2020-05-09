#! /usr/bin/env lua53

-- Import Section
--
local reduce	  = require'carlos.fold'.reduce
local slice	  = require'carlos.fold'.slice
local map	  = require'carlos.fold'.map
local into	  = require'carlos.fold'.into

local urldecode   = require'carlos.ferre'.urldecode
local queryDB	  = require'carlos.ferre'.queryDB
local context	  = require'lzmq'.context
local pollin	  = require'lzmq'.pollin

--local feed	= require'carlos.ferre.feed'
--local bixolon   = require'carlos.ferre'.bixolon -- XXX

local assert	  = assert
local concat	  = table.concat
local insert	  = table.insert

local print	  = print
local stdout	  = io.stdout
local popen	  = io.popen

-- No more external access after this point
_ENV = nil -- or M

-- Local Variables for module-only access
--
local BIXOLON    = 'ipc://bixolon.ipc'

local PRINTER	 = 'nc -N 192.168.3.21 9100'

--------------------------------
-- Local function definitions --
--------------------------------
--

local function bixolon( data )
    local skt = popen(PRINTER, 'w')
    if #data > 8 then
	data = slice(4, data, into, {})
	reduce(data, function(v) skt:write(concat(v,'\n'), '\n') end)
    else
	skt:write( concat(data,'\n') )
    end
    skt:close()
end


---------------------------------
-- Program execution statement --
---------------------------------
--
-- Initilize server(s)
local CTX = context()

local server = assert(CTX:socket'PULL')

assert( server:bind( BIXOLON ) )

print('\nSuccessfully bound to:', BIXOLON, '\n')
--
-- -- -- -- -- --
--

while true do
print'+\n'

    pollin{server}

	local msg = server:recv_msgs() -- receive(server)

	bixolon( msg )

end
