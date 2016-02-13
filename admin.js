
        "use strict";

	var admin = {
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	};

	window.onload = function addFuns() {
	    const PEOPLE = admin.PEOPLE;
	    const DBs = [ PEOPLE ];

	    PEOPLE.load = function() {
		let tb = document.getElementById('tabla-entradas');
		let row = nombre => tb.insertRow().appendChild(document.createTextNode(nombre));
		IDB.readDB( PEOPLE ).openCursor( cursor => { if(!cursor){ return } row(cursor.value.nombre); cursor.continue(); } );
	    };

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt); };

 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }
	    
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();
	};


