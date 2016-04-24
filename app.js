
        "use strict";

	var ferre = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' }
	};

	window.onload = function() {
	    const DATA = ferre.DATA;
	    const PEOPLE = ferre.PEOPLE;
	    const DBs = [ DATA, TICKET, PEOPLE ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    ferre.startSearch = BROWSE.startSearch;

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.scroll = BROWSE.scroll;

	    // SQL

	    SQL.DB = 'ticket';

	    // TICKET

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.ttotal = document.getElementById( TICKET.ttotalID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    let id_tag = TICKET.TAGS.none;

	    ferre.add2bag = function( e ) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		return IDB.readDB( TICKET ).get( clave )
		    .then( q => { if (q) { return Promise.reject('Item is already in the bag.'); } else { return IDB.readDB( DATA ).get(clave); } } )
		    .then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } )
		    .then( TICKET.add );
	    };

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

	    ferre.emptyBag = TICKET.empty;

	    ferre.print = function(a) {
		id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		document.getElementById('dialogo-persona').showModal();
	    };

	    // PEOPLE | SET Person Dialog

	    PEOPLE.load = function loadPEOPLE() {
		const dialog = document.getElementById('dialogo-persona');
		let ol = document.createElement('ol');
		dialog.appendChild(ol);

		function plain(obj) {
		    let ret = [];
		    for (let k in obj) { ret.push(k, obj[k]); }
		    return ('args=' + ret.join('+'));
		}

		function sending(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    dialog.close();
		    e.target.textContent = '';
		    let objs = ['id_tag='+id_tag, 'id_person='+k];
		    return IDB.readDB( TICKET ).count()
			.then( q => objs.push( 'count='+q ) )
			.then( () => IDB.readDB( TICKET ).openCursor( cursor => {
			    if (cursor) {
				let o = TICKET.obj(cursor.value);
				objs.push( plain(o) );
				cursor.continue();
			    } else { SQL.print( objs ) } } ) )
		    	.then( ferre.emptyBag );
		}

		IDB.readDB( PEOPLE ).openCursor( cursor => {
		    if(cursor) {
			ol.appendChild( document.createElement('li') ).textContent = cursor.value.nombre;
			cursor.continue();
		    } else {
			let ie = document.createElement('input');
			ie.type = 'text'; ie.size = 1;
			ie.addEventListener('keydown', sending); // print | send | else
			dialog.appendChild( ie );
		    }
		})
	    };

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

