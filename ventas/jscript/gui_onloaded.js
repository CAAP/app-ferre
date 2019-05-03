	// HEADER
	(function() {
	    let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
	    document.getElementById('notifications').innerHTML = now(FORMAT);
	    document.getElementById("eventos").innerHTML = 'Loading ...'
	    document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 3.0 + ' | cArLoS&trade; &copy;&reg;';
	})();

	// Init & Load DBs
	(function() {
	    const STORES = DATA.STORES;
	    let lvers = document.getElementById('db-vers');
	    STORES.VERS.inplace = o => { lvers.textContent = o.week + 'V' + o.vers; return true; };

	    function isPriceless(store) {
		if (store.STORE == 'precios')
		    return XHR.getJSON(store.VERS)
			      .then( STORES.VERS.update );
		else
		    return Promise.resolve(true);
	    }

	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
			    return IDB.populateDB(k).then(() => isPriceless(k) );
			else
			    return Promise.resolve(true);
		     }
	        );
	    }

	    document.getElementById('pacman').style.visibility = 'visible';
	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then(db => Promise.all(UTILS.mapObj(STORES, k => {
			const store = STORES[k];
			if (store.INDEX == undefined) // case of STORES that have no actual DB on disk
			    return Promise.resolve(true);
			else {
			    store.CONN = db.CONN;
			    return ifLoad(store);
			}
		   })))
		   .then(() => { document.getElementById('pacman').style.visibility = 'hidden'; STORES.PRICE.INDEX = 'desc'; });

	})();

	// FERRE
	(function() {
	    ferre.origin = document.location.origin+':5040/';
	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {UTILS.clearTable(r); BROWSE.rows(q,r);} return q;};
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    ferre.keyPressed = BROWSE.keyPressed;
	    ferre.startSearch = BROWSE.startSearch;
	    ferre.scroll = e => {if (BROWSE.lis.childElementCount > 0) {return BROWSE.scroll(e)} };
	    ferre.cerrar = DATA.close;
	})();

	// TICKET
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

//		const tcount = document.getElementById(TICKET.tcountID);  XXX
		const ttotal = document.getElementById( TICKET.ttotalID );
		const persona = document.getElementById('personas');

		persona.dataset.id = 0;

		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		function getPrice( o ) {
		    let clave = UTILS.asnum(o.clave);
		    return IDB.readDB( PRICE )
			.get( clave )
			.then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject('Item not found in DB: ' + clave) } } ) // ITEM NOT FOUND or REMOVED
		}

		function add2bag(clave) {
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }
		    return getPrice( {clave: clave, qty: 1, precio: 'precio1', rea: 0} )
			.then( w => Object.assign(w, {totalCents: uptoCents(w)}) )
			.then( TICKET.add );
		}

		TICKET.getPrice = getPrice;

		TICKET.total = cents => { ttotal.textContent = '$' + (cents / 100).toFixed(2); }; //
		// tcount.textContent = TICKET.items.size; XXX

		TICKET.extraEmpty = () => { ttotal.textContent = ''; }; // tcount.textContent = ''; 

		ferre.emptyBag = () => { TICKET.empty(); return ferre.xget('delete', {pid: Number(persona.value)}) };

		ferre.menu = e => {
		    if (persona.value == 0) { return; }
		    const clave = UTILS.asnum(e.target.parentElement.dataset.clave);
		    add2bag(clave);
		};

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return Promise.resolve();}
		const pid = Number(persona.dataset.id);

		if (pid == 0) { TICKET.empty(); return Promise.resolve(); } // should NEVER happen XXX

		let objs = ['pid='+pid];
		TICKET.myticket.style.visibility = 'hidden';
		TICKET.items.forEach( item => objs.push( 'query=' + TICKET.plain(item) ) );

		return ferre.xget(a, objs).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
	    };

	    // XXX in case of mulitiple elements on the ticket, one should consider
	    // dividing the load by splitting the elements to be sent XXX
	    ferre.split = function() {
	    };

	})();


	// PEOPLE - Multi-User support
	(function() {
	    var PEOPLE = {
		id: [''],
		nombre: {},
		tabs: new Map()
	    };

	    ferre.TABS = PEOPLE.tabs;

	    const persona = document.getElementById('personas');
	    let fetchMe = o => TICKET.getPrice( o ).then( TICKET.add );
	    let recreate = a => Promise.all( a.map( fetchMe ) ); // .then( () => Promise.resolve() ).then( () => {tcount.textContent = TICKET.items.size;} )
	    function tabs(k) { persona.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k)); } }

	    ferre.tab = () => {
		const pid = Number(persona.value);
		ferre.print('tabs').then( () => tabs(pid) );
	    };

	    let opt = document.createElement('option');
	    opt.value = 0;
	    opt.label = '';
	    opt.selected = true;
	    persona.appendChild(opt);

	    XHR.getJSON('json/people.json').then(a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); persona.appendChild(opt); } ) );
	})();


