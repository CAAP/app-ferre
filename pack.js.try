	"use strict";

	var PACK = {
	    STORE: 'paquetes',
	    INDEX: 'desc',
	    update: a => {
		let os = IDB.write2DB( PACK );
		return Promise.all( a.map( o => os.get( o.clave ).then( q => {
		    if (q) { return Object.assign(q, o); } else { return o; } } )
		    .then( os.put )
		    .then( DATA.inplace )
		    .then( o => { if (o.desc.startsWith('VV')) { return os.delete( o.clave ) } } )
		) );
	    }
	};
