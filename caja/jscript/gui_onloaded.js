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
		   .then(() => { STORES.PRICE.INDEX = 'desc'; STORES.CUSTOMERS.INDEX = 'rfc'; });

	})();

	// CAJA
	(function() {
	    caja.origin = document.location.origin+':5040/';

	    DATA.inplace = () => Promise.resolve(true);

	    let mymenu = document.getElementById("menu");

	    caja.menuToggle = p => { mymenu.style.display = p ? 'inline' : 'none'; };
	})();

	// FACTURAR
	(function() {
	    const butt = document.querySelector('button[name="facturar"]');
	    butt.disabled = false;

	    caja.taxme = function(w) {
		if (!(butt.disabled || w.uidSAT))
		    butt.disabled = true;
		return w;
	    };

	})();

	// PEOPLE
	(function() {
	    const persona = document.getElementById('personas');

	    XHR.getJSON('/json/people.json').then(a => a.forEach( p => {
		let opt = document.createElement('option');
		caja.NAMES.set(p.id, p.nombre.toUpperCase());
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
	    const butt = document.querySelector('button[name="facturar"]');

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

	    caja.emptyBag = () => {
		caja.UIDS.clear();
		caja.UPDATED = false;
		butt.disabled = false;
		return TICKET.empty();
	    }

	    caja.print = function(a) { // a E { ticket, bixolon, pagado, msgs }
		if (TICKET.items.size == 0)
		    return Promise.resolve();

		if (caja.OLD && a == 'pagado')
		    return window.alert('No se puede modificar un ticket que no fue creado HOY!');

		if (caja.UPDATED && a == 'msgs')
		    return window.alert('El ticket ha sido modificado y debe ser impreso antes de ser enviado!');

		if (!caja.UPDATED && a == 'ticket' )
		    a = 'bixolon';

		if (!caja.UPDATED)
		    return caja.UIDS.forEach(uid => caja.xget(a, {pid: persona.value, uid: uid})); // XXX XHR.get(caja.origin + a + '?' + uid)
		else {
		    let objs = ['pid=A'];
		    TICKET.items.forEach( item => objs.push( 'query=' + TICKET.plain(item) ) );
		    if (TICKET.items.size > 4)
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
		    .then( caja.taxme ) // can be taxed?
		    .then( TICKET.show ) // instead of TICKET.add
		    .catch( e => console.log(e) );
	    };

	    caja.add2caja = function(w) {
		const tr = cajita.querySelector('[data-uid="'+w.uid+'"]');
		if (tr) { cajita.removeChild(tr); }
//		if (tr) { tr.lastChild.textContent = w.tag; return Promise.resolve(true); }
		let row = cajita.insertRow(0);
		row.dataset.uid = w.uid;
		w.nombre = caja.NAMES.get( UTILS.asnum(w.uid.match(/\d+$/)) ) || 'CAJA';
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
	    const ctls = document.getElementById('fechas');
	    const UIDS = caja.UIDS;
	    const TODAY = new Date().toISOString().substring(0, 10);

	    function getUID(e) {
		const fruit = sessionStorage.fruit;
		const uid = e.target.parentElement.dataset.uid;
		UIDS.add( uid );
		if (UIDS.size > 1) { caja.UPDATED = true; }
		if (!uid.includes(TODAY)) { caja.OLD = true; }
		return caja.xget('uid', {uid: uid, fruit: fruit});
	    }

	    caja.add2fecha = function(w) {
		let row = cajita.insertRow(0);
		row.dataset.uid = w.uid;
		w.nombre = caja.NAMES.get( UTILS.asnum(w.uid.match(/\d+$/)) );
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

	    caja.toggleDates = () => ctls.classList.toggle('oculto');

	})();


	// FACTURAR
	(function() {
	    const row = document.getElementById('my-rfc');
	    const p = row.parentNode;
	    let CUSTOMERS = DATA.STORES.CUSTOMERS;
	    const IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const NN = 4;

	    function wipe() {
		while (row.nextSibling)
		    p.removeChild(row.nextSibling);
	    }

	    function setRFC(el) {
		return function(e) {
		    const rfc = e.target.textContent;
		    el.value = rfc;
		    IDB.readDB( CUSTOMERS ).get( rfc ).then(o => { el.title = o.razonSocial; }, er => console.log('Error searching RFC: '+ er));
		    wipe();
		};
	    }

	    function browse(e) {
		const ff = setRFC(e);
		let k = 0;
		return function(cursor) {
		    if (!cursor) { return Promise.reject('No suitable value found!'); }
		    const o = cursor.value;
		    const cell = p.insertRow().insertCell();
		    cell.appendChild( document.createTextNode(o.rfc) );
		    cell.classList.add('addme');
		    cell.onclick = ff;
		    if (++k == NN) { return true; }
		    cursor.continue();
		};
	    }

	    caja.getRFC = function(e) {
		switch (e.key || e.which) {
		    case 'Escape':
		    case 'Esc':
		    case 27:
			e.target.value = "";
			break;
		    default: break;
		}
		wipe();
		if (e.value.length == 0) { return Promise.resolve(false); }
		const ans = e.value.toUpperCase().trim();
		if (ans.length > 7) { return Promise.resolve(false); } 
		return IDB.readDB( CUSTOMERS ).index(IDBKeyRange.lowerBound(ans, true), 'next', browse(e)).catch(er => console.log('Error searching by RFC: '+er));
	    };
	})();
/*
	    const tabla = document.getElementById('taxes');
	    const ctls = document.getElementById('factura');

	    let dub = false;
	    function addField(k) {
		let row = dub ? tabla.rows.item(tabla.rows.length-1) : tabla.insertRow();
		// input & defaults
		let cell = row.insertCell();
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 8; ie.name = k;
		ie.placeholder = k; ie.disabled = true;
		// specifics
		switch(k) {
		    case 'razonSocial':
		    case 'calle':
				ie.size = 35; cell.colSpan = 2; break;
		    case 'correo': ie.size = 20; cell.colSpan = 2; break;
		    default: dub = !dub;
		}
		cell.appendChild( ie );
	    }

	    caja.setRFC = () => UTILS.forObj(caja.RFC, k => { ctls.querySelector('input[name='+k+']').value = caja.RFC[k] || ''; } );

	    caja.toggleRFC = () => ctls.classList.toggle('oculto');

	    XHR.getJSON('/json/rfc.json').then(a => a.forEach( addField ));

*/
