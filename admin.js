
        "use strict";

	var admin = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' }
	};

	window.onload = function() {
	    const DATA = admin.DATA;
	    const DBs = [ DATA, TICKET ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    admin.startSearch = BROWSE.startSearch;

	    admin.keyPressed = BROWSE.keyPressed;

	    admin.scroll = BROWSE.scroll;

	    // UPDATES

	    const diag = document.getElementById('dialogo-cambios');

	    function displayRecord( k, v ) {
		let p = document.createElement('p');
		p.appendChild( document.createTextNode(k) );
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 5;
		p.appendChild( ie );
		diag.appendChild( p );
	    }

	    function getRecord( clave ) {
		return SQL.get( {clave: clave} )
		.then( JSON.parse )
		.then( a => a[0] )
		.then( q => { for (var k in q) { displayRecord(k, q[k]); } } );
	    }

	    // SQL

	    SQL.DB = 'ferre';

	    // TICKET

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.ttotal = document.getElementById( TICKET.ttotalID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    let id_tag = TICKET.TAGS.none;

	    admin.clickItem = e => TICKET.remove( e.target.parentElement );

	    admin.emptyBag = TICKET.empty;

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

