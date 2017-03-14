	"use strict";

	var DATA = { VERSION: 1, DB: 'datos', STORES: [] };

	(function() {
	    let precios = {
		STORE: 'precios',
		KEY: 'clave',
		INDEX: [{key: 'desc'}, {key: 'faltante'}, {key: 'proveedor'}],
		FILE: '/ferre/precios.lua',
		VERS: '/ferre/version.lua',
		MAP: function(q) {
		    q.precios = {};
		    for (let i=1; i<4; i++) {
			let k = 'precio'+i;
			if (q[k] > 0)
			    q.precios[k] = q[k].toFixed(2) + ' / ' + q['u'+i];
		    }
		    return q;
		}
	    };

	    let paquetes = {
		STORE: 'paquetes',
		KEY: 'clave',
		INDEX: [{key:'uid'}, {key:'tag'}] // 'desc'
	    };

	    DATA.STORES.push( paquetes, precios );

	    function ifLoad(k) { return IDB.readDB(k).count().then( q => { if (q == 0 && k.FILE) { return IDB.populateDB(k) } } ); }

	    // LOAD DBs
 	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		    .then( ret => Promise.all( DATA.STORES.map( store => {store.CONN = ret.CONN; return ifLoad(store);} ) ) )
		    .then( () => document.querySelector('a').click() );
	})();
