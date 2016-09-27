        "use strict";

	var ferre = {};

	window.onload = function() {
	    const DBs = [ DATA ]; // , TICKET

	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

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
//		let inObs = diagI.querySelector('input[list=obs]'); // faltantes
		let lsObs = document.getElementById('obs'); // faltantes
		let clave = -1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };
//		function clearTable(tb) { inObs.value = ''; while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }; //recycle?
		function choice(s) { let opt = document.createElement('option'); opt.value = s; lsObs.appendChild( opt ); }

		ferre.menu = e => {
		    const slc = document.getElementById('personas');
		    if (slc.value == 0) { return; }
//		    if (e.target.parentElement.querySelector('.faltante'))
//			return;
		    clave = asnum(e.target.parentElement.dataset.clave);
		    diagI.showModal();
//		    IDB.readDB( DATA ).get( clave ).then(p => {if (p) { clearTable(lsObs); if (p.obs) { p.obs.forEach( choice ) }}}).then( () => diagI.showModal());
		};

		// Add: faltante XXX
		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }
		    return IDB.readDB( DATA ).get( clave )
			.then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } )
			.then( TICKET.add );
		};

		ferre.faltante = function() {
		    if (window.confirm('Enviar reporte de faltante?'))
			SQL.update({clave: clave, faltante: 1, tbname: 'faltantes', vwname: 'faltantes', id_tag: 'u'})
			    .then( () => diagI.close() );

		};
	    })();

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

		const persona = document.getElementById('personas'); // XXX refactor all instances of this

	    ferre.emptyBag = () => { TICKET.empty(); SQL.print({id_tag: 'd', pid: Number(persona.value)}); ferre.saveme(); } //

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return;}
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
//		let rfc = ''; if (a == 'facturar') { rfc = arg1; };
		const pid = Number(document.getElementById('personas').dataset.id);

		let objs = ['tag='+a, 'person='+(PEOPLE.id[pid] || 'NAP'),'id_tag='+id_tag, 'pid='+pid, 'count='+TICKET.items.size]; // , 'rfc='+rfc

		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return SQL.print( objs ); //.then( ferre.emptyBag ); //then( doprint ).then( ferre.emptyBag )
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
		slc.dataset.id = 0;
		const tag = document.getElementById('tag');

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function data( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ); }
		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }
		function recreate(q) { return q.split('&').reduce( (p, s) => p.then( () => data(a2obj(s.split('+'))) ), Promise.resolve() ); }
		function tabs(k) { slc.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k).query); } }

		function msg_tag(pid) {
			tag.textContent = PEOPLE.horarios.get(pid);
			if ((tag.textContent[0] == 'E') ^ (tag.classList.contains('entrada')))
			    tag.classList.toggle('entrada');
		}

		ferre.tag = () => {
		    const pid = Number(slc.value);
		    if (PEOPLE.horarios.has(pid)) { msg_tag( pid ); }
		    else { tag.textContent = ''; }
		};

		ferre.tab = () => {
		    const pid = Number(slc.value); // alt: slc.value
	// message tag
		    ferre.tag();
	// if ticket-bag is not empty then send info to server for broadcasting
		    if (TICKET.items.size > 0) { ferre.print('guardar').then( ferre.emptyBag ).then( () => tabs(pid) ); }
		    else { tabs(pid); }
		};

		(function nobody(){
		    let opt = document.createElement('option');
		    opt.value = 0;
		    opt.label = '';
		    opt.selected = true;
		    slc.appendChild(opt);
		})();

		ferre.saveme = () => { slc.value = 0; ferre.tab(); }

		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); slc.appendChild(opt); } ) );

		PEOPLE.horarios = new Map();
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
		    esource.addEventListener("tabs", function(e) {
			console.log("tabs event received.");
			JSON.parse( e.data ).forEach( o => PEOPLE.tabs.set(o.pid, o) );
		    }, false);
		    esource.addEventListener("update", function(e) {
			console.log("update event received.");
			DATA.update( JSON.parse(e.data) );
		    }, false);
		    esource.addEventListener("faltante", function(e) {
			console.log("faltante event received.");
			DATA.update( JSON.parse(e.data) )
			    .then( () => { let r = document.body.querySelector('tr[data-clave="'+JSON.parse(e.data)[0].clave+'"]'); if (r) { r.querySelector('.desc').classList.add('faltante'); } } );
		    }, false);
		    esource.addEventListener("delete", function(e) {
			const pid = Number(e.data);
			PEOPLE.tabs.delete(pid);
			console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    }, false);
		    esource.addEventListener("entradas", function(e) {
			JSON.parse( e.data ).forEach( p => PEOPLE.horarios.set( p.pid, p.tag + ' ' + p.hora ) );
			ferre.tag();
		    }, false);
		})();

	};

