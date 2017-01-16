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

	    TICKET.show = () => { TICKET.myticket.style.display = 'block'; TICKET.myticket.style.visibility = 'visible'; }

	    (function() {
		const diagI = document.getElementById('dialogo-item');
		const tcount = document.getElementById(TICKET.tcountID);
		const ttotal = document.getElementById( TICKET.ttotalID );
		const persona = document.getElementById('personas');
		const diagF = document.getElementById('dialogo-faltante');
		const obs = diagF.querySelector('input[name=obs]');

		let clave = -1;
		persona.dataset.id = 0;
//		const tag = document.getElementById('tag');

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		TICKET.total = cents => { ttotal.textContent = ' $' + (cents / 100).toFixed(2); tcount.textContent = TICKET.items.size;};

		TICKET.extraEmpty = () => { ttotal.textContent = ''; tcount.textContent = ''; };

		ferre.emptyBag = () => {TICKET.empty(); return SQL.print({id_tag: 'd', pid: Number(persona.value)})};

		ferre.menu = e => {
		    if (persona.value == 0) { return; }
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

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return Promise.resolve();}
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		const pid = Number(persona.dataset.id);

		let objs = ['id_tag='+id_tag, 'pid='+pid]; // , 'rfc='+rfc // 'person='+(PEOPLE.id[pid] || 'NAP'), // 'tag='+a, // , 'count='+TICKET.items.size

		TICKET.myticket.style.visibility = 'hidden';

		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return SQL.print( objs ).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
	    };

		ferre.enviarF = e => SQL.update({clave: clave, faltante: 1, obs: obs.value, tbname: 'faltantes', id_tag: 'u'}).then( () => { obs.value = ''; ferre.cerrar(e); } );

		ferre.faltante = e => IDB.readDB( PRICE ).get( clave ).then( w => { ferre.cerrar(e); if (w.faltante < 2) {obs.value = w.obs; diagF.showModal();} } );

	    // PEOPLE - Multi-User support

		function data( o ) { return IDB.readDB( PRICE ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ); }
		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }
//		function recreate(q) { return  q.split('&').reduce( (p, s) => p.then( () => data(a2obj(s.split('+'))) ), Promise.resolve() ); }
		let recreate = q => Promise.all( q.split('&').map(s => data(a2obj(s.split('+')))) ).then( () => Promise.resolve() ).then( () => {tcount.textContent = TICKET.items.size;} );
		function tabs(k) { persona.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k).query); } }

		ferre.tab = () => {
		    const pid = Number(persona.value);
	/* message tag
		    ferre.tag(); */
		    ferre.print('guardar').then( () => tabs(pid) );
//		    if (TICKET.items.size > 0) { ferre.print('guardar').then( () => tabs(pid) ); }
//		    else { tabs(pid); }
		};

		ferre.saveme = () => { persona.value = 0; ferre.tab(); }

		(function appendNobody(){
		    let opt = document.createElement('option');
		    opt.value = 0;
		    opt.label = '';
		    opt.selected = true;
		    persona.appendChild(opt);
		})();

		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); persona.appendChild(opt); } ) );


	    })();

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

/*
	    ferre.surtir = function() {
		let objs = [];
		TICKET.items.forEach( item => objs.push( 'args=clave+'+item.clave+'+qty+'+item.qty  ) );
		return XHR.get('/ticket/surtir.lua?'+objs.join('&')).then( ferre.saveme );
	    };
*/

	    // SQL

	    SQL.DB = document.location.origin + ':8081';

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

