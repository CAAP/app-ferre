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
	    DATA.inplace = () => Promise.resolve(true);
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

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
	})();

	// UPDATES
	(function() {
	    let tabla = document.getElementById('tabla-cambios');
	    let costos = new Set(['costo', 'impuesto', 'descuento', 'rebaja', 'prc1', 'prc2', 'prc3']);
	    let records = new Map()
	    let fields = new Set();


	    function outputs(row, k) {
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 5; ie.name = k; ie.disabled = true;
		row.insertCell().appendChild( ie );
		fields.add( k );
		return ie;
	    }

	    admin.addField = k => {
		if (k.startsWith()) { return; } // taken care of by prc_
		let row = tabla.insertRow();
		// input && defaults
		let cell = row.insertCell();
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 5; ie.name = k;
		// specifics
		switch(k) {
		    case 'desc': ie.size = 40; cell.colSpan = 3; break;
		    case 'clave': ie.disabled = true; outputs(row, 'uidSAT').disabled = false; break;
		    case 'costo': outputs(row, 'costol'); break;
		}
		if (k.startsWith('prc')) { outputs(row, k.replace('prc', 'u')).disabled = false; outputs(row, k.replace('prc', 'precio')); }
		if (costos.has(k)) { ie.type = 'number'; }
		cell.appendChild( ie );
 		fields.add( k );
	    };

	    function setfields( o ) {
		let costol = o.costol
		let a = Object.assign({}, o, {costol: (costol/1e4).toFixed(2)});
		Array.from(fields).filter( k => k.startsWith('prc') ).forEach( k => {a[k.replace('prc', 'precio')] = (a[k]*costol/1e4).toFixed(2)} );
		fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = a[k] || '' } );
	    }

	    function fetch(k, f) {
		if (records.has(k)) { return f( records.get(k) ); }
		return admin.xget('query', {clave: k, fruit: localStorage.fruit});
	    }

	    admin.getRecord = function(e) {
		let clave = UTILS.asnum(e.target.parentElement.dataset.clave);
		fetch(clave, setfields);
	    };

	    admin.setRecord = function(a) {
		records.set(a.clave, a);
		setfields(a);
	    };

	})();

	// FEED
	(function() {

	})();


