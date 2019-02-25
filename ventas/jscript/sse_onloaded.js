	(function() {
	    var ferre = {
		updateItem: TICKET.update,
		clickItem: e => TICKET.remove( e.target.parentElement )
	    };
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
	    ferre.scroll = BROWSE.scroll;
	    ferre.cerrar = DATA.close;
	})();

	// TICKET
	(function() {
	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

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

		const diagI = document.getElementById('dialogo-item');
		const tcount = document.getElementById(TICKET.tcountID);
		const ttotal = document.getElementById( TICKET.ttotalID );
		const persona = document.getElementById('personas');

		let clave = -1;
		persona.dataset.id = 0;

		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		function getPrice( o ) {
		    let clave = UTILS.asnum(o.clave);
		    return IDB.readDB( PRICE )
			.get( clave )
			.then( w => { if (w) { return Object.assign( o, w, {id: clave} ) } else { return Promise.reject('Item not found in DB: ' + clave) } } ) // ITEM NOT FOUND or REMOVED
		}

		TICKET.total = cents => { ttotal.textContent = (cents / 100).toFixed(2); tcount.textContent = TICKET.items.size;}; //' $' + 

		TICKET.extraEmpty = () => { ttotal.textContent = ''; tcount.textContent = ''; };

		ferre.emptyBag = () => { TICKET.empty(); return xget('print', {id_tag: 'd', pid: Number(persona.value)}) };

		ferre.menu = e => {
		    if (persona.value == 0) { return; }
		    clave = UTILS.asnum(e.target.parentElement.dataset.clave); // XXX one can use this instead: diagI.returnValue = clave;
		    diagI.showModal();
		};

		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; }
		    return getPrice( {clave: clave, qty: 1, precio: 'precio1', rea: 0} )
			.then( w => Object.assign(w, {totalCents: uptoCents(w)}) )
			.then( TICKET.add );
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
	})();


	// PEOPLE - Multi-User support
	(function() {
	    const persona = document.getElementById('personas');
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

	    let opt = document.createElement('option');
	    opt.value = 0;
	    opt.label = '';
	    opt.selected = true;
	    persona.appendChild(opt);

//	    PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); persona.appendChild(opt); } ) );
	})();

	// Init & Load DBs
	(function() {
	    const STORES = DATA.STORES;
	    let lvers = document.getElementById('db-vers');
	    STORES.VERS.update = o => {
		localStorage.vers = o.vers;
		localStorage.week = o.week;
		lvers.textContent = ' | ' + o.week + 'V' + o.vers;
	    };

	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
		    return IDB.populateDB(k)
			      .then(() => XHR.getJSON(k.VERS))
			      .then(o => {localStorage.vers = o.vers; localStorage.week = o.week;})
			      .then(() => { STORES.PRICE.INDEX = 'desc'; });
			else
		    STORES.PRICE.INDEX = 'desc';
		     }
	        );
	    }


	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then(db => Promise.all(UTILS.mapObj(STORES, k => {
			const store = STORES[k];
			if (store.INDEX == undefined)
			    return Promise.resolve(true);
			else {
			    store.CONN = db.CONN;
			    return ifLoad(store);
			}
		   })));

	})();

/*
	UTILS.origin = document.location.origin;

	// fetch, update VERSION
	(function() {
	    const origin = UTILS.origin;
	    const week = localStorage.week;
	    const vers = localStorage.vers;
		// current WEEK, VERS

	    if (WEEK != week || VERS != vers) {
		console.log('Version mismatch: '+WEEK+' ('+week+'), V'+VERS+' (V'+vers+')');
		XHR.getJSON(origin+':5040/update?oweek='+week+'&overs='+vers+'&nweek='+WEEK)
			.then( updateMe );
	    }
	})();
*/

/*
	// connect DATA's EVENT-SOURCE
	(function() {
	    const origin = UTILS.origin;
	    const STORES = DATA.STORES;

	    let updateMe = data => Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) );

	    let esource = new EventSource(origin + ":5030");

	    esource.addEventListener('update', e => {
		const week = localStorage.week;
		const vers = localStorage.vers;
		const data = JSON.parse(e.data);
		const upd = data.find(o => {return o.store == 'VERS'});
		console.log('Update event ongoing!');
		if (upd.week == week && upd.prev == vers)
		    updateMe(data);
	    }, false);
	})();
*/

/*
	(function() {
	    function a2obj( a ) {
		const M = a.length/2;
		let o = {};
		for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; }
		return o;
	    }

		esource.addEventListener("tabs", function(e) {
		    console.log("tabs event received.");
		    JSON.parse( e.data ).forEach( o => PEOPLE.tabs.set(o.pid, o.query.split('&').map(s => a2obj(s.split('+')))) );  //data(a2obj(s.split('+'))))
		}, false);
		esource.addEventListener("delete", function(e) {
		    const pid = Number(e.data);
		    PEOPLE.tabs.delete(pid);
		    console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		}, false);

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();
*/

