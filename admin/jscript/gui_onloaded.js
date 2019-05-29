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

	// ADMIN
	(function() {
	    admin.origin = document.location.origin+':5040/';
	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {UTILS.clearTable(r); BROWSE.rows(q,r);} return q;};
//	    DATA.inplace = () => Promise.resolve(true);
	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let sat = row.insertCell();
		clave.classList.add('pesos'); sat.appendChild( document.createTextNode( a.uidSAT || '' ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let costol = row.insertCell();
		costol.classList.add('total'); costol.classList.add('precio1');
		costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
	    };

	    admin.keyPressed = BROWSE.keyPressed;
	    admin.startSearch = BROWSE.startSearch;
	    admin.scroll = BROWSE.scroll;
	})();

	// UPDATES
	(function() {
	    let tabla = document.getElementById('tabla-cambios');
	    let tkt = document.getElementById('ticket');
	    let costos = new Set(['costol', 'impuesto', 'descuento', 'rebaja', 'prc1', 'prc2', 'prc3']);
	    let records = new Map()
	    let fields = new Set();

	    function outputs(row, k) {
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 7; ie.name = k; ie.disabled = true; // ie.size = 7;
		row.insertCell().appendChild( ie );
		fields.add( k );
		return ie;
	    }

	    admin.addField = k => {
		if (k.startsWith('u')) { return; } // already taken into account by prc_
		let row = tabla.insertRow();
		// input && defaults
		row.insertCell().appendChild( document.createTextNode(k.replace('prc', 'precio')) );
		let cell = row.insertCell();
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 8; ie.name = k;
		// specifics
		switch(k) {
		    case 'desc': ie.size = 40; cell.colSpan = 3; break;
		    case 'clave': ie.disabled = true; outputs(row, 'uidSAT').disabled = false; break;
		    case 'costo': outputs(row, 'costol'); break;
		    case 'fecha': ie.disabled = true; break;
		}
		if (k.startsWith('prc')) { outputs(row, k.replace('prc', 'u')).disabled = false; outputs(row, k.replace('prc', 'precio')); }
		if (costos.has(k)) { ie.type = 'number'; }
		cell.appendChild( ie );
 		fields.add( k );
	    };

	    function setfields( o ) {
		tkt.dataset.clave = o.clave;
		let costol = o.costol
		let a = Object.assign({}, o, {costol: (costol/1e4).toFixed(2)});
		Array.from(fields).filter( k => k.startsWith('prc') ).forEach( k => {a[k.replace('prc', 'precio')] = (a[k]*costol/1e4).toFixed(2)} );
		fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = a[k] || '' } );
	    }

	    function fetch(k, f) {
		if (records.has(k)) { return f( CHANGES.fetch(k, records.get(k)) ); }
		return admin.xget('query', {clave: k, fruit: localStorage.fruit});
	    }

	    function costol(o) { o.costol = o.costo*(100+(Number(o.impuesto)||0))*(100-(Number(o.descuento)||0))*(1-(Number(o.rebaja)||0)/100) }

	    function compute(clave, k) {
		if (k.startsWith('prc'))
		    fetch(clave, setfields);
		else
		    fetch( clave, w => { costol(w); records.set(clave,w); setfields(w); } );
	    }

	    admin.getRecord = function(e) {
		let clave = UTILS.asnum(e.target.parentElement.dataset.clave);
		fetch(clave, setfields);
		tkt.style.visibility = 'visible';
	    };

	    admin.setRecord = function(a) {
		records.set(a.clave, a);
		setfields(a);
	    };

	    admin.cancelar = () => { records.clear(); CHANGES.clear(); tkt.querySelectorAll('input').forEach(i => { i.value = ''}); tkt.dataset.clave = ''; };

	    admin.anUpdate = function(e) {
		const clave = UTILS.asnum(tkt.dataset.clave);
		let k = e.target.name;
		let v = e.target.value;
		CHANGES.update(clave, k, v);
		if (costos.has(k)) { compute(clave, k); }
	    };

	    function update(clave, o) { return XHR.get(admin.origin + 'update?' + UTILS.encPpties(Object.assign(o,{clave: clave, tbname: 'datos', fruit: localStorage.fruit}))) }

	    admin.enviar = function(fecha) {
		const clave = UTILS.asnum(tkt.dataset.clave);
		if (fecha)
		    CHANGES.update(clave, 'fecha', true);
		if (window.confirm('Estas seguro de realizar los cambios?'))
		    CHANGES.get(clave, update)
		    .then( admin.cancelar );
	    };

	})();

