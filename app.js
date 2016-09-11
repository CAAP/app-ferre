        "use strict";

	var ferre = {};

	window.onload = function() {
	    const DBs = [ DATA ]; // , TICKET

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    ferre.startSearch = BROWSE.startSearch;

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.scroll = BROWSE.scroll;

	    ferre.cerrar = e => e.target.closest('dialog').close();

	    // TICKET

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    (function() {
		let diagI = document.getElementById('dialogo-item');
		let clave = -1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		ferre.asnum = e => { e.target.value = Number(e.target.textContent) };

		ferre.menu = e => { clave = asnum(e.target.parentElement.dataset.clave); diagI.showModal(); };

		// Add: faltante XXX
		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; } // MAYBE not needed by diagI XXX
		    return IDB.readDB( DATA ).get( clave )
			.then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } ) // MAYBE simplified by diagI XXX
			.then( TICKET.add );
		};
	    })();

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

	    ferre.emptyBag = TICKET.empty;

	    ferre.print = function(a) {
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
//		let rfc = ''; if (a == 'facturar') { rfc = arg1; };
		const pid = document.getElementById('personas').dataset.id;
		let objs = ['id_tag='+id_tag, 'id_person='+pid, 'count='+TICKET.items.size ]; // , 'rfc='+rfc

		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return SQL.print( objs ).then( ferre.emptyBag );
	    };

	    (function() {
		const ttotal = document.getElementById( TICKET.ttotalID );
		TICKET.total = function(amount) { ttotal.textContent = (amount / 100).toFixed(2); };
	    })();

	    // SQL

	    SQL.DB = document.location.origin + ':8081';

	    // PEOPLE - Multi-User support

	    (function() {
		const slc = document.getElementById('personas');
		slc.dataset.id = 1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function data( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ); }
		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }
		function recreate(q) { return q.split('&args=').reduce( (p, s) => p.then( () => data(a2obj(s.split('+'))) ), Promise.resolve() ); }
		function tabs(k) { slc.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k).query); } }

		ferre.tab = e => {
		    const pid = Number(e.target.value);
	// if ticket-bag is not empty then send info to server for broadcasting
		    if (TICKET.items.size > 0) { ferre.print('guardar').then( () => tabs(pid) ); }
		    else { tabs(pid); }
		};

		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); slc.appendChild(opt); } ) );

	    })();

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // HEADER
	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	// SERVER-SIDE EVENT SOURCE
		(function() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.onmessage = e => console.log( 'id: ' + e.lastEventId );
		    esource.addEventListener("save", function(e) {
			const o = JSON.parse( e.data )[0];
			o.query = o.query.substr(o.query.search('args') + 5);
			PEOPLE.tabs.set(Number(o.id_person), o);
			console.log('Message for: ' + PEOPLE.id[o.id_person]);
		    }, false);
		    esource.addEventListener("delete", function(e) {
			const pid = Number(e.data);
			PEOPLE.tabs.delete(pid);
			console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    }, false);
		})();

	};

