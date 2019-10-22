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

	// CAJA
	(function() {
	    caja.origin = document.location.origin+':5040/';
	    DATA.inplace = () => Promise.resolve(true);

	    let mymenu = document.getElementById("menu");

	    caja.menuToggle = p => { mymenu.style.display = p ? 'inline' : 'none'; };
	})();

	// PEOPLE
	(function() {
	    const persona = document.getElementById('personas');
	    XHR.getJSON('/json/people.json').then(a => a.forEach( p => {
		let opt = document.createElement('option');
		opt.value = p.id;
		opt.appendChild(document.createTextNode(p.nombre));
		persona.appendChild(opt); } ) );
	})();

	// TICKET
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    const BRUTO = 1.16;
	    const IVA = 7.25;
	    const tiva = document.getElementById( TICKET.tivaID );
	    const tbruto = document.getElementById( TICKET.tbrutoID );
	    const ttotal = document.getElementById( TICKET.ttotalID );

	    const cajita = document.getElementById('tabla-caja');
	    const persona = document.getElementById('personas');

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    TICKET.extraEmpty = () => true;

	    function tocents(x) { return (x / 100).toFixed(2); };

	    TICKET.total = function(amount) {
		tiva.textContent = tocents( amount / IVA );
		tbruto.textContent = tocents( amount / BRUTO );
		ttotal.textContent = '$' + tocents( amount );
	    };

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    UTILS.redondeo = x => x; // TEMPORAL x FACTURAR

	    caja.emptyBag = () => { caja.UIDS.clear(); caja.UPDATED = false; return TICKET.empty() }

	    caja.print = function(a) {
		if (TICKET.items.size == 0)
		    return Promise.resolve();

		if (caja.UPDATED && a != 'ticket')
		    return Promise.resolve();

		if (a == 'msgs')
		    return caja.UIDS.forEach(uid => caja.xget(a, {pid: persona.value, uid: uid}));

		if (!caja.UPDATED && a == 'ticket' )
		    a = 'bixolon';

		if (!caja.UPDATED)
		    return caja.UIDS.forEach(uid => XHR.get(caja.origin + a + '?' + uid)); // XXX checar para asi poder usar un objecto como en todos lo casos y fusionar con 'msgs'
		else {
		    let objs = ['pid=A'];
		    TICKET.items.forEach( item => objs.push( 'query=' + TICKET.plain(item) ) );
		    if (TICKETS.items.size > 4)
			return caja.xpost(a, objs).then( caja.emptyBag );
		    else
			return caja.xget(a, objs).then( caja.emptyBag );
		}
	    };

	})();

	// FEED
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    const cajita = document.getElementById('tabla-caja');
	    const UIDS = caja.UIDS;

	    function getUID(e) {
		const uid = e.target.parentElement.dataset.uid;
		const fruit = sessionStorage.fruit;
		UIDS.add( uid );
		if (UIDS.size > 1) { caja.UPDATED = true; }
		return caja.xget('uid', {uid: uid, fruit: fruit});
	    }

	    caja.add2bag = function(o) {
		const clave = UTILS.asnum(o.clave);
		if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }

		return IDB.readDB( PRICE )
		    .get( clave )
		    .then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject() } } )
		    .then( TICKET.show ) // instead of TICKET.add
		    .catch( e => console.log(e) );
	    };

	    caja.add2caja = function(w) {
		let row = cajita.insertRow(0);
		row.dataset.uid = w.uid;
		for (let k of ['time', 'nombre', 'count', 'total']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		let tag = row.insertCell();
		tag.classList.add('addme');
		tag.appendChild( document.createTextNode( w.tag ) );
		tag.onclick = getUID;
	    };

	    caja.reset = () => UTILS.clearTable( cajita );

	})();

	// LEDGER
	(function() {
	    const cajita = document.getElementById('tabla-fechas');
	    const UIDS = caja.UIDS;

	    function getUID(e) {
		const fruit = sessionStorage.fruit;
		const uid = e.target.parentElement.dataset.uid;
		UIDS.add( uid );
		if (UIDS.size > 1) { caja.UPDATED = true; }
		return caja.xget('uid', {uid: uid, fruit: fruit});
	    }

	    caja.add2fecha = function(w) {
		let row = cajita.insertRow(0);
		row.dataset.uid = w.uid;
		for (let k of ['time', 'nombre', 'total']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		row.lastChild.classList.add('pesos') ; // total en centavos
		let tag = row.insertCell();
		tag.classList.add('addme');
		tag.appendChild( document.createTextNode( w.tag ) );
		tag.onclick = getUID;
	    };

	    caja.refresh = () => UTILS.clearTable( cajita );

	    caja.ledger = function(e) {
		let fecha = e.target.value
		if (fecha.length > 0)
		    return caja.xget('ledger', {fruit: sessionStorage.fruit, uid: fecha+'T'});
	    };

	})();

