
        "use strict";

	var caja = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'}
	};

	window.onload = function addFuns() {
	    const DATA = caja.DATA;
	    const PEOPLE = caja.PEOPLE;
	    const DBs = [ DATA, PEOPLE, TICKET ];

	    // SQL

	    SQL.DB = 'caja';

	    // TICKET

	    let ids = [];

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.ttotal = document.getElementById( TICKET.ttotalID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    caja.updateItem = TICKET.update;

	    caja.clickItem = e => TICKET.remove( e.target.parentElement );

	    caja.emptyBag = TICKET.empty

	    caja.print = function(a) {
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
		const mybag = TICKET.bag;

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		function merge( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ).then( () => { mybag.lastChild.dataset.uid = o.uid } ) }

		let add2bag = uid => SQL.get( { uid: uid } ).then( JSON.parse ).then( objs => objs.reduce( (seq, o) => seq.then( () => merge(o) ), Promise.resolve() ) );

		let removeItem = uid => Array.from(mybag.children).filter( row => (row.dataset.uid == uid) ).reduce( (seq, tr) => seq.then( () => TICKET.remove(tr) ), Promise.resolve() );

		function add2caja(w) {
		    let row = cajita.insertRow(0);
		
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid;
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value); else removeItem(e.target.value); } );
		    row.insertCell().appendChild(ie);

		    w.nombre = PEOPLE.id[asnum(w.uid.substring(20))] || 'NaN';
		    w.time = w.uid.substr(11, 8);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    for (let k of ['time', 'nombre', 'count', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}

//		XHR.getJSON('caja/ping.lua').then( objs => objs.forEach( add2caja ) );

	// SERVER-SIDE EVENT SOURCE
	    (function() {
		let esource = new EventSource("http://192.168.1.14:8080");
//		esource.onerror = function(e) { console.log(e.target); };
//		esource.onopen = function(e) { console.log('Opening...'); };
		esource.onmessage = e => console.log( 'id: ' + e.lastEventId );
		esource.addEventListener("feed", function(e) {
		    console.log('FEED message received\n');
		    JSON.parse( e.data ).forEach( add2caja );
		}, false);
	    })();

	    })();

	};


