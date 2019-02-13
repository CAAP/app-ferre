	var DATA = { VERSION: 1, DB: 'datos', STORES: [] };

	(function() {
	    let precios = {
		STORE: 'precios',
		KEY: 'clave',
		INDEX: [ {key: 'desc'} ], // {key: 'faltante'}, {key: 'proveedor'}
		FILE: '/app/precios.lua',
		VERS: '/app/version.lua',
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

	    DATA.STORES.push( precios ); // works only for precios XXX

/*		
	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
		    return IDB.populateDB(k) // only works for precios XXX
			      .then(() => XHR.getJSON(k.VERS))
			      .then(o => {localStorage.vers = o.vers; localStorage.week = o.week;});
		     }
	        );
	    }

	    // LOAD DBs
 	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then( ret => Promise.all( DATA.STORES.map( store => {store.CONN = ret.CONN; return ifLoad(store);} ) ) )
		   .then( () => document.querySelector('a').click() );
*/
	})();


	window.onload = function() {
	    const xhro = document.location.origin + ':5050';
	    let esource = new EventSource(xhro);
	    esource.addEventListener("vers", function(e) {
		console.log( JSON.parse(e.data) );
	    }, false);


	};

