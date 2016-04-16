
        "use strict";

	var admin = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'}
	};

	window.onload = function addFuns() {
	    const DATA = admin.DATA;
	    const PEOPLE = admin.PEOPLE;
	    const DBs = [ DATA, PEOPLE, TICKET ];

	    // SQL

	    SQL.DB = 'caja';

	    // TICKET

	    let ids = [];

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.ttotal = document.getElementById( TICKET.ttotalID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

//	    ferre.updateItem = e => TICKET.update(e).then( w => SQL.update(w) );

//	    admin.item2bin = e => TICKET.remove(e).then( clave => SQL.remove(clave) );

	    admin.emptyBag = TICKET.empty

	    admin.print = function(a) {
		tag = a;
		document.getElementById('dialogo-persona').showModal();
	    };

	    // PEOPLE

	    PEOPLE.load = function() {
		const tb = document.getElementById('tabla-entradas');
		PEOPLE.id = [];
		function add2row(nombre) { tb.insertRow().appendChild(document.createTextNode(nombre)) }
		IDB.readDB( PEOPLE ).openCursor( cursor => {
		    if(!cursor){ return }
		    let nombre = cursor.value.nombre;
		    add2row(nombre);
		    PEOPLE.id[cursor.value.id] = nombre;
		    cursor.continue();
		});
	    };

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt); };

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }
	    
	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	// ping CAJA
	    (function() {

		const cajita = document.getElementById('tabla-caja');

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

		function merge( o ) { IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ) }

		let add2bag = uid => SQL.get( { uid: uid } ).then( JSON.parse ).then( objs => objs.forEach( merge ) );

		function add2caja(w) {
		    let row = cajita.insertRow(0);
		
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid;
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value) } );
		    row.insertCell().appendChild(ie);

		    w.nombre = PEOPLE.id[asnum(w.uid.substring(20))] || 'NaN';
		    w.time = w.uid.substr(11, 8);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    for (let k of ['time', 'nombre', 'count', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}

		XHR.getJSON('caja/ping.lua').then( objs => objs.map( add2caja ) );

/*
	// SERVER-SIDE EVENT SOURCE
	    (function() {
		let esource = new EventSource("caja/stream.lua");
		esource.onerror = function(e) { alert("Error while running GET: caja/ping.lua"); };
		esource.addEventListener("feed", function(e) {
		    JSON.parse(e.data).then( objs => objs.map( add2caja );
		}, false);
	    })();
*/

	    })();

	};


