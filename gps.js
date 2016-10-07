        "use strict";

	var app = {};

	window.onload = function() {
	    const DBs = [ DATA ]; // , TICKET

	    app.reloadDB = function reloadDB() { return IDB.clearDB( DATA ).then( () => IDB.populateDB( DATA ) ); };

		    let objStore = IDB.write2DB( app );
		    return objStore.get( desc ).then( q => {
			if (q) { q.proveedor = e.target.value; q.proveedor = e.target.value; return q; }
			else { Promise.fail('No key found!'); }
		    }, e => console.log("Error searching by desc: " + e)  )
		    .then( objStore.put );

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
	    app.updateGPS = function(e) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		let gps = e.target.value;
		return XHR.get('/ferre/gps.lua?clave='+clave+'&gps='+gps)
		    .then(() => {
			let os = IDB.write2DB( app );
			return os.get( clave ).then( q => { if (q) { q.gps = gps; os.put( q ); } else { Promise.reject('Element not found!'); } } );
		    });
	    };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let gps = row.insertCell();
		let ie = document.createElement('input'); ie.type = 'text'; ie.size = 5; ie.value = a.gps || '';
		ie.addEventListener('change', app.updateGPS ); gps.appendChild( ie );
	    };

	    app.startSearch = BROWSE.startSearch;

	    app.keyPressed = BROWSE.keyPressed;

	    app.scroll = BROWSE.scroll;

	    app.cerrar = e => e.target.closest('dialog').close();

	    // HEADER

	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	    // LOAD DBs
 		if (IDB.indexedDB)
		    Promise.all( DBs.map( IDB.loadDB ) ).then( () => console.log('Success!') );
	    })();

	};

