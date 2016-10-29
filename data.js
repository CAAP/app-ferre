	"use strict";

	var DATA = { VERSION: 1,
		DB: 'datos',
		STORE: 'precios',
		INDEX: 'desc',
		MAP: function(q) {
		    q.precios = {};
		    for (let i=1; i<4; i++) {
			let k = 'precio'+i;
			if (q[k] > 0)
			    q.precios[k] = q[k].toFixed(2) + ' / ' + q['u'+i];
		    }
		    return q;
		},
		clearTable: tb => { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } },
		update: a => {
		    let os = IDB.write2DB( DATA );
		    return Promise.all( a.map( o => os.get( o.clave ).then( q => {
			    if (q) { return Object.assign(q, o); } else { return o; } } )
			    .then( DATA.MAP )
			    .then( os.put )
			    .then( DATA.inplace )
			    .then( o => { if (o.desc.startsWith('VV')) { return os.delete( o.clave ) } } )
			) );
		}
	 };
