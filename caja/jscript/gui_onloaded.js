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

	// CAJA
	(function() {
	    caja.origin = document.location.origin+':5040/';
	    DATA.inplace = () => Promise.resolve(true);
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    caja.keyPressed = BROWSE.keyPressed;
	    caja.startSearch = BROWSE.startSearch;
	    caja.scroll = BROWSE.scroll;
	    caja.cerrar = DATA.close;
	})();

	// TICKET
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    const BRUTO = 1.16;
	    const IVA = 7.25;
	    const tiva = document.getElementById( TICKET.tivaID );
	    const tbruto = document.getElementById( TICKET.tbrutoID );
	    const ttotal = document.getElementById( TICKET.ttotalID );

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    TICKET.extraEmpty = () => true;

	    function tocents(x) { return (x / 100).toFixed(2); };

	    TICKET.total = function(amount) {
		tiva.textContent = tocents( amount / IVA );
		tbruto.textContent = tocents( amount / BRUTO );
		ttotal.textContent = tocents( amount );
	    };

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    UTILS.redondeo = x => x; // TEMPORAL x FACTURAR

	    caja.emptyBag = () => { caja.UIDS.clear(); caja.UPDATED = false; return TICKET.empty() }

	    caja.print = function(a) {
		if (TICKET.items.size == 0) { return Promise.resolve() }
		if (!caja.UPDATED)
		    caja.UIDS.forEach(uid => XHR.get(caja.origin + 'bixolon?' + uid));
		else {
		    let objs = ['pid=A'];
		    TICKET.items.forEach( item => objs.push( 'query=' + TICKET.plain(item) ) );
		    return caja.xget(a, objs);
		}
	    };

	})();

	// FEED
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    const cajita = document.getElementById('tabla-caja');

	    caja.add2bag = function(o) {
		const clave = UTILS.asnum(o.clave);
		if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }

		return IDB.readDB( PRICE )
		    .get( clave )
		    .then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject() } } )
		    .then( TICKET.add ) // instead of TICKET.show
		    .catch( e => console.log(e) );
	    };

	    caja.add2caja = function(w) {
		let row = cajita.insertRow(0);
		row.dataset.uid = w.uid;
		for (let k of ['time', 'nombre', 'count', 'total', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
	    };

	    caja.getUID = e => {
		const UIDS = caja.UIDS;
		const uid = e.target.parentElement.dataset.uid;
		const fruit = localStorage.fruit;
		UIDS.add( uid );
		if (UIDS.size > 1) { caja.UPDATED = true; }
		return caja.xget('uid', {uid: uid, fruit: fruit});
	    };

	})();


