
        "use strict";

	window.onload = function() {
	    admin.addFuns();
	    admin.header();
	    admin.footer();
	    if (admin.indexedDB) { admin.loadDBs(); }
	    else { alert('IDBIndexed not available.'); }
	};

	var admin = {
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	};

	admin.addFuns = function addFuns() {
	    const PEOPLE = admin.PEOPLE;
	    const DBs = [ PEOPLE ];

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) };

 	    admin.indexedDB = IDB.indexedDB;

	    admin.loadDBs = function() { DBs.map( db => IDB.loadDB(db) ); };

	    admin.header = function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    }

	    admin.footer = function() {
		document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';
	    };

	    PEOPLE.load = function() {
		let tb = document.getElementById('tabla-entradas');
		let row = nombre => tb.insertRow().appendChild(document.createTextNode(nombre));
		IDB.readDB( PEOPLE ).openCursor( cursor => { if(!cursor){ return } row(cursor.value.nombre); cursor.continue(); } );
	    };

	};


