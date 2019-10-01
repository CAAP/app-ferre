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
		   .then(() => { STORES.PRICE.INDEX = 'desc'; });

	})();

	// FERRE
	(function() {
	    ferre.origin = document.location.origin+':5040/';
	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {UTILS.clearTable(r); BROWSE.rows(q,r);} return q;};

	    ferre.getUID = e => ferre.xget('uid', {uid: e.target.innerHTML, fruit: sessionStorage.fruit});
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    BROWSE.query = o => ferre.xget('query', o);

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

		const tcount = document.getElementById(TICKET.tcountID);
		const ttotal = document.getElementById( TICKET.ttotalID );
		const persona = document.getElementById('personas');
		const destino = document.getElementById('destinos');

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

		TICKET.total = cents => { ttotal.textContent = '$' + (cents / 100).toFixed(2); tcount.textContent = TICKET.items.size; };

		TICKET.extraEmpty = () => { ttotal.textContent = ''; tcount.textContent = ''; };

		ferre.emptyBag = () => { TICKET.empty(); return ferre.xget('delete', {pid: Number(persona.value)}) };

		ferre.addItem = e => {
		    if (!persona.disabled) { return; }
		    const clave = UTILS.asnum(e.target.parentElement.dataset.clave);
		    add2bag(clave);
		};

	    ferre.print = function(a) {
		if (TICKET.items.size == 0) {return Promise.resolve();}
		const pid = Number(persona.value);

		if (pid == 0) { TICKET.empty(); return Promise.resolve(); } // should NEVER happen XXX

		if (a == 'destinos') { a = destinos.value; };

		let objs = ['pid='+pid];
		TICKET.myticket.style.visibility = 'hidden';
		TICKET.items.forEach( item => objs.push( 'query=' + TICKET.plain(item) ) );

		if (TICKET.items.size > 4) {
		    return ferre.xpost(a, objs).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
		} else {
		return ferre.xget(a, objs).then( TICKET.empty, () => {TICKET.myticket.style.visibility = 'visible'} );
		}
	    };

	    ['ticket', 'presupuesto', 'surtir'].forEach( lbl => {
		    let opt = document.createElement('option');
		    opt.value = lbl;
		    opt.appendChild(document.createTextNode(lbl));
		    destino.appendChild(opt);
	    });

	})();

	// PEOPLE - Multi-User support
	(function() {
	    var PINS   = new Map();
	    var NAMES  = new Map();

	    const tcount = document.getElementById(TICKET.tcountID);
	    const persona = document.getElementById('personas');
	    const pcode = document.getElementById('pincode');
	    const mensaje = document.getElementById('mensajes');
	    const sesion = document.getElementById('sesion');

		let opt = document.createElement('option');
		persona.appendChild(opt);
		opt.value = 0;
		opt.label = '';
		opt.selected = true;

	    ferre.PINS = PINS;

	    let nadie = () => { opt.selected = true; persona.disabled = false; mensaje.innerHTML = ''; sesion.innerHTML = ''; }

	    let fetchMe = o => {
		if (TICKET.items.has( o.clave )) {
		    console.log('Item is already in the bag.');
		    return false;
		} else
		    return TICKET.getPrice( o ).then( TICKET.add );
	    }

	    let recreate = a => Promise.all( a.map( fetchMe ) ).then( () => Promise.resolve() ).then( () => {tcount.textContent = TICKET.items.size;} );

	    ferre.recreate = recreate;

	    ferre.tab = () => {
		const pid = Number(persona.value);
		if (pid == 0) { return; }
		pcode.disabled = false;
		pcode.focus();
	    };

	    ferre.login = () => {
		if (!pcode.value.match(/\d{1,4}/)) { pcode.value = ''; return alert("PIN invalido!"); };
		const pid = Number(persona.value);
		let pin = PINS.get(pid);
		if (pin == 0) {
		    pin = Number(pcode.value);
		    ferre.xget('pins', {pid: pid, pincode: pin});
		}
		if (Number(pcode.value) == pin) {
		    pcode.value = '';
		    pcode.disabled = true;
		    persona.disabled = true;
		    sessionStorage.pid = pid; // send fruit+pid
		    sesion.innerHTML = NAMES.get(pid);
		    ferre.xget('login', sessionStorage);
		} else {
		    pcode.value = '';
		    return alert("PIN incorrecto!");
		}
	    };

	    ferre.message = m => {
		const a = m.match(/pid=(\d+)&uid=([^&]+)/);
		if (a[1] == persona.value)
		    mensaje.innerHTML = a[2];
	    };

	    ferre.logout = () => ferre.print('tabs').then( nadie );

	    XHR.getJSON('/json/people.json').then(
		a => a.forEach( p => {
		    const pid = Number(p.id);
		    PINS.set(pid, 0); // initialize to 0
		    NAMES.set(pid, p.nombre.toUpperCase());
		    let opt = document.createElement('option');
		    opt.value = pid;
		    opt.appendChild(document.createTextNode(p.nombre));
		    persona.appendChild(opt); } ) );
	})();


