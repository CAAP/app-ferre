        "use strict";

	var ferre = {};

	window.onload = function() {

	    const PRICE = DATA.STORES.PRICE;

	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {DATA.clearTable(r); BROWSE.rows(q,r);} return q;};

	    const xhro = document.location.origin + ':8081';

	    const xget = (q, o) => XHR.get( xhro + '/' + q +' .lua?' + DATA.asstr(o) );

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.startSearch = BROWSE.startSearch;

	    ferre.scroll = BROWSE.scroll;

	    ferre.cerrar = DATA.close;

	    // TICKET

	    TICKET.load_tags();

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

//XXX WHY?	    TICKET.show = () => { TICKET.myticket.style.display = 'block'; TICKET.myticket.style.visibility = 'visible'; }

	    ferre.rabatt = function() {
		function prom(row) {
		    if (!row.classList.contains('rabatt')) {
			let i = row.querySelector('input[name=rea]');
			i.value = 7;
			TICKET.update({target: i});
		    }
		}
		Array.from(TICKET.bag.children).forEach(prom);
	    };

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

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }; // UNIFY XXX
		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		function getPrice( o ) {
		    let clave = asnum(o.clave);
		    return IDB.readDB( PRICE )
			.get( clave )
			.then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject('Item not found in DB: ' + clave) } } ) // ITEM NOT FOUND or REMOVED
		}

		TICKET.total = cents => { ttotal.textContent = (cents / 100).toFixed(2); tcount.textContent = TICKET.items.size;}; //' $' + 

		TICKET.extraEmpty = () => { ttotal.textContent = ''; tcount.textContent = ''; };

		ferre.emptyBag = () => { TICKET.empty(); return xget('print', {id_tag: 'd', pid: Number(persona.value)}) };

		ferre.menu = e => {
		    if (persona.value == 0) { return; }
		    clave = asnum(e.target.parentElement.dataset.clave); // XXX one can use this instead: diagI.returnValue = clave;
		    diagI.showModal();
		};

		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }
		    return getPrice( {clave: clave, qty: 1, precio: 'precio1', rea: 0} )
			.then( w => Object.assign(w, {totalCents: uptoCents(w)}) )
			.then( TICKET.add );
//			.catch( e => console.log(e) )
		};

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return Promise.resolve();}
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		const pid = Number(persona.dataset.id);

		if (pid == 0) { TICKET.empty(); return Promise.resolve(); } // it should NEVER happen XXX

		let objs = ['id_tag='+id_tag, 'pid='+pid];
		TICKET.myticket.style.visibility = 'hidden';
		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return xget('print', objs ).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
	    };

		ferre.enviarF = e => xget('update', {clave: clave, faltante: 1, obs: obs.value, tbname: 'faltantes', id_tag: 'u'}).then( () => { obs.value = ''; ferre.cerrar(e); } );

		ferre.faltante = e => IDB.readDB( PRICE ).get( clave ).then( w => { ferre.cerrar(e); if (w.faltante < 2) {obs.value = w.obs; diagF.showModal();} } );

	    // PEOPLE - Multi-User support

		let fetchMe = o => getPrice( o ).then( TICKET.add );
		let recreate = a => Promise.all( a.map( fetchMe ) ).then( () => Promise.resolve() ).then( () => {tcount.textContent = TICKET.items.size;} );
		function tabs(k) { persona.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k)); } }

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
		return xget('surtir', objs).then( ferre.saveme );
	    };
*/

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

		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }

		function addEvents() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		    esource.addEventListener("tabs", function(e) {
		 	console.log("tabs event received.");
		    	JSON.parse( e.data ).forEach( o => PEOPLE.tabs.set(o.pid, o.query.split('&').map(s => a2obj(s.split('+')))) );  //data(a2obj(s.split('+'))))

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

