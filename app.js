        "use strict";

	var ferre = {};

	window.onload = function() {

	    const PRICE = DATA.STORES.PRICE;

	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {DATA.clearTable(r); BROWSE.rows(q,r);} return q;};

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.startSearch = BROWSE.startSearch;

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

		ferre.menu = e => {
		    const slc = document.getElementById('personas');
		    if (slc.value == 0) { return; }
		    clave = asnum(e.target.parentElement.dataset.clave); // XXX one can use this instead: diagI.returnValue = clave;
		    diagI.showModal();
		};

		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }
		    return IDB.readDB( PRICE ).get( clave )
			.then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } )
			.then( TICKET.add );
		};

		let diagF = document.getElementById('dialogo-faltante');
		let obs = diagF.querySelector('input[name=obs]');

		ferre.enviarF = e => SQL.update({clave: clave, faltante: 1, obs: obs.value, tbname: 'faltantes', id_tag: 'u'}).then( () => { obs.value = ''; ferre.cerrar(e); } );

		ferre.faltante = e => IDB.readDB( PRICE ).get( clave ).then( w => { ferre.cerrar(e); obs.value = w.obs; diagF.showModal(); } );
	    })();

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

	    const persona = document.getElementById('personas'); // XXX refactor all instances of this

	    ferre.emptyBag = () => { TICKET.empty(); return SQL.print({id_tag: 'd', pid: Number(persona.value)}) }

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return Promise.resolve();}
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		const pid = Number(document.getElementById('personas').dataset.id);

		let objs = ['id_tag='+id_tag, 'pid='+pid]; // , 'rfc='+rfc // 'person='+(PEOPLE.id[pid] || 'NAP'), // 'tag='+a, // , 'count='+TICKET.items.size

		TICKET.myticket.style.visibility = 'hidden';

		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return SQL.print( objs ).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
	    };

	    ferre.surtir = function() {
		let objs = [];
		TICKET.items.forEach( item => objs.push( 'args=clave+'+item.clave+'+qty+'+item.qty  ) );
		return XHR.get('/ticket/surtir.lua?'+objs.join('&')).then( ferre.saveme );
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
//		const tag = document.getElementById('tag');

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function data( o ) { return IDB.readDB( PRICE ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ); }
		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }
		function recreate(q) { return q.split('&').reduce( (p, s) => p.then( () => data(a2obj(s.split('+'))) ), Promise.resolve() ); }
		function tabs(k) { slc.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k).query); } }

		ferre.tab = () => {
		    const pid = Number(slc.value);
	/* message tag
		    ferre.tag(); */
		    ferre.print('guardar').then( () => tabs(pid) );
//		    if (TICKET.items.size > 0) { ferre.print('guardar').then( () => tabs(pid) ); }
//		    else { tabs(pid); }
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

	    })();

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
		function addEvents() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		    esource.addEventListener("tabs", function(e) {
		 	console.log("tabs event received.");
		    	JSON.parse( e.data ).forEach( o => PEOPLE.tabs.set(o.pid, o) );
		    }, false);
		    esource.addEventListener("delete", function(e) {
			const pid = Number(e.data);
			PEOPLE.tabs.delete(pid);
			console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    }, false);
		}

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();

	};

