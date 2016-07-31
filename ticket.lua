local sql = require'carlos.sqlite'

local conn = sql.connect''
assert(conn, "Failed connecting to 'tickets.sql'")

local data = { '.TS', 'c s s s.',
'FERRETERIA AGUILAR',
'FERRETERIA Y REFACCIONES EN GENERAL',
'Benito Juárez 1C, Ocotlán, Oaxaca',
'Tel. (951) 57-10560',
'.T&', 'c c c c.',
'=	=	=	=',
'CLAVE	CNT	PRECIO	TOTAL',
'=	=	=	=' }

local function printItem(w)
    data[#data+1] = '.T&\nc s s s.'
    data[#data+1] = w.desc
    data[#data+1] = '.T&\nc c c c.'
    data[#data+1] = string.format('%s\t%d\t%f\t%f', w.clave, w.qty, w[w.precio], w.totalCents)
end

local function getItem(clave)

    printItem(w)
    data[#data+1] = '.T&\nc s s s.\nGRACIAS POR SU COMPRA\n.TE'
return print(table.concat(data, '\n'))
end



