
        "use strict";

	var admin = {
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	};

	window.onload = function addFuns() {
	    const PEOPLE = admin.PEOPLE;
	    const DBs = [ PEOPLE ];

	    PEOPLE.load = function() {
		const tb = document.getElementById('tabla-entradas');
		PEOPLE.all = {};
		function add2row(nombre) { tb.insertRow().appendChild(document.createTextNode(nombre)) }
		IDB.readDB( PEOPLE ).openCursor( cursor => {
		    if(!cursor){ return }
		    let nombre = cursor.value.nombre;
		    add2row(nombre);
		    PEOPLE.all[cursor.value.id] = nombre;
		    cursor.continue();
		});
	    };

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt); };

 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }
	    
	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	    (function() {
		const cajita = document.getElementById('tabla-caja');

		function add2caja(w) {
		    let row = cajita.insertRow();
		    row.dataset.daytime = w.daytime; row.dataset.id_ticket = w.id_ticket;
		    w.nombre = PEOPLE.all[w.id_person] || 'NaN'; w.time = w.daytime.substring(3);
		    for (let k of ['time', 'nombre', 'id_ticket', 'count']) { row.appendChild( document.createTextNode(w[k]) ); }
		}

		admin.loadTickets = function (objs) { objs.forEach( add2caja ); }

	    })();

	// SERVER-SIDE EVENT SOURCE
	    (function() {
		let esource = new EventSource("/ticket/ping.lua");
		esource.onerror = function(e) { alert("Error while running GET: /ticket/ping.lua"); };
		esource.addEventListener("feed", function(e) {
		    admin.loadTickets( JSON.parse(e.data) );
		}, false);
	    })();

	};


