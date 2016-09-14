
        "use strict";

	var admin = {};

	window.onload = function() {
	    const DBs = [ DATA, UPDATES ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = clave => IDB.readDB( DATA ).get( clave );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    admin.startSearch = BROWSE.startSearch;

	    admin.keyPressed = BROWSE.keyPressed;

	    admin.scroll = BROWSE.scroll;

	    // UPDATES

	    UPDATES.diag = document.getElementById('dialogo-cambios');
	    UPDATES.tabla = document.getElementById('tabla-cambios');
	    UPDATES.ups = document.getElementById('update');
	    UPDATES.lista = document.getElementById('tabla-update');

	    function makeDisplay( k ) {
		let row = UPDATES.tabla.insertRow();
		row.insertCell().appendChild( document.createTextNode(k) );
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 5; ie.name = k;
		if (k=='desc') { ie.size = 40; }
		row.insertCell().appendChild( ie );
	    }

	    UPDATES.lista.style.cursor = 'pointer';

	    XHR.getJSON('/ferre/header.lua').then( a => a.forEach( makeDisplay ) );

	    admin.anUpdate = e => UPDATES.anUpdate( e.target.name, e.target.value );

	    admin.getRecord = e => UPDATES.getRecord( e.target.parentElement.dataset.clave );

	    admin.clickItem = e => UPDATES.remove( e.target.parentElement );

	    admin.emptyBag = UPDATES.emptyBag;

	    // SQL

	    SQL.DB = 'ferre';

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // SET HEADER
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	};

