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

	// FACTURAS
	(function() {
	    facturas.origin = document.location.origin+':5040/';
	    DATA.inplace = () => Promise.resolve(true);
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

	    facturas.emptyBag = TICKET.empty;

	})();


	// Cliente - RFC
	(function() {
	    let tabla = document.getElementById('taxes');
	    let dub = false;

	    tabla.style.visibility = 'collapse';

	    facturas.addField = k => {
		let row = dub ? tabla.rows.item(tabla.rows.length-1) : tabla.insertRow();
		// input && defaults
		let cell = row.insertCell();
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 8; ie.name = k;
		ie.placeholder = k;
		// specifics
		switch(k) {
		    case 'razonSocial':
		    case 'calle':
				ie.size = 35; cell.colSpan = 2; break;
		    case 'correo': ie.size = 20; cell.colSpan = 2; break;
		    default: dub = !dub;
		}
		cell.appendChild( ie );
// 		fields.add( k );
	    };

	    facturas.toggleForm = () => {
		if (tabla.style.visibility == 'collapse')
		    tabla.style.visibility = 'visible';
		else
		    tabla.style.visibility = 'collapse';
	    };
	})();


	// FEED
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    const facturas = document.getElementById('tabla-facturas');

	    function getUID(e) {
		const uid = e.target.parentElement.dataset.uid;
		const fruit = localStorage.fruit;
		TICKET.empty(); // in case there's a TICKET already shown
		return facturas.xget('uid', {uid: uid, fruit: fruit});
	    }

	    facturas.add2bag = function(o) {
		const clave = UTILS.asnum(o.clave);
		if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }

		return IDB.readDB( PRICE )
		    .get( clave )
		    .then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject() } } )
		    .then( TICKET.add ) // instead of TICKET.show
		    .catch( e => console.log(e) );
	    };

	    facturas.addInvoice = function(w) {
		let row = facturas.insertRow(0);
		row.dataset.uid = w.uid;
		for (let k of ['time', 'razonSocial', 'total']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		let tag = row.insertCell();
		tag.classList.add('addme');
		tag.appendChild( document.createTextNode( 'mostrar' ) );
		tag.onclick = getUID;
	    };
	})();


