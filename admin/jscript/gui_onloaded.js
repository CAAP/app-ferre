	// HEADER
	(function() {
	    let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
	    document.getElementById('notifications').innerHTML = now(FORMAT);
	    document.getElementById("eventos").innerHTML = 'Loading ...'
	    document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 3.0 + ' | cArLoS&trade; &copy;&reg;';
	})();

	// Init & Load DBs
	(function() {
	    const STORES = DATA.STORES;
	    let lvers = document.getElementById('db-vers');
	    STORES.VERS.inplace = o => { lvers.textContent = o.week + 'V' + o.vers; return true; };

	    function isPriceless(store) {
		if (store.STORE == 'precios')
		    return XHR.getJSON(store.VERS)
			      .then( STORES.VERS.update );
		else
		    return Promise.resolve(true);
	    }

	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
			    return IDB.populateDB(k).then(() => isPriceless(k) );
			else
			    return Promise.resolve(true);
		     }
	        );
	    }

	    document.getElementById('pacman').style.visibility = 'visible';
	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then(db => Promise.all(UTILS.mapObj(STORES, k => {
			const store = STORES[k];
			if (store.INDEX == undefined) // case of STORES that have no actual DB on disk
			    return Promise.resolve(true);
			else {
			    store.CONN = db.CONN;
			    return ifLoad(store);
			}
		   })))
		   .then(() => { document.getElementById('pacman').style.visibility = 'hidden'; STORES.PRICE.INDEX = 'desc'; });

	})();

	// ADMIN
	(function() {
	    admin.origin = document.location.origin+':5040/';
	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {DATA.clearTable(r); BROWSE.rows(q,r);} return q;};
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

		// REALLY necessary still? XXX
	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let sat = row.insertCell();
		clave.classList.add('pesos'); sat.appendChild( document.createTextNode( a.uidSAT || '' ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let costol = row.insertCell();
		costol.classList.add('total'); costol.classList.add('precio1');
		costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
	    };



	    admin.keyPressed = BROWSE.keyPressed;
	    admin.startSearch = BROWSE.startSearch;
	    admin.scroll = BROWSE.scroll;
//	    ferre.cerrar = DATA.close; XXX is it needed here & 'ventas'?
	})();

	
