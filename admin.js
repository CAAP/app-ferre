        "use strict";

	var admin = {};

	window.onload = function() {
	    const COST = DATA.STORES.COST;

	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {DATA.clearTable(r); BROWSE.rows(q,r); r.classList.add('modificado');} return q;};

	    admin.cerrar = e => e.target.closest('dialog').close(); // XXX unify

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = clave => IDB.readDB( COST ).get( clave );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( COST ).index( a, b, f ); // XXX readDB proveedores HERE

	    BROWSE.rows = function(a, row) {
		// XXX readDB proveedores & get costol
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let costol = row.insertCell();
		costol.classList.add('total'); costol.classList.add('precio1');
		IDB.readDB( COSTO ).get(a.clave).then(q => costol.appendChild( document.createTextNode( (q.costol / 1e4).toFixed(2) ) ))
//		costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
	    };

	    admin.startSearch = BROWSE.startSearch;

	    admin.keyPressed = BROWSE.keyPressed;

	    admin.scroll = BROWSE.scroll;

	    // UPDATES

	    // cambios dialog - lista de cambios
	    (function() {
		let tabla = document.getElementById('tabla-cambios'); // tabla inside dialog
		let udiag = document.getElementById('dialogo-cambios');
		let lista = document.getElementById('tabla-update');
		let ups = document.getElementById('ticket');

		let fields = new Set();
		let cambios = new Map();
		let records = new Map();
		let costos = new Set(['costo', 'impuesto', 'descuento', 'prc1', 'prc2', 'prc3']);

		function outputs(row, k) {
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 5; ie.name = k; ie.disabled = true;
		    row.insertCell().appendChild( ie );
		    fields.add( k );
		    return ie;
		}

		function addfield( k ) {
		    if (k.startsWith('u')) { return; }
		    let row = tabla.insertRow();
		    // label
		    row.insertCell().appendChild( document.createTextNode(k.replace('prc', 'precio')) );
		    // input
		    let cell = row.insertCell();
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 5; ie.name = k;
		    if (k == 'desc') { ie.size = 40; cell.colSpan = 3; }
		    if (k == 'clave') { ie.disabled = true; }
		    if (k.startsWith('prc')) { outputs(row, k.replace('prc', 'u')).disabled = false; outputs(row, k.replace('prc', 'precio')); }
		    if (k == 'costo') { outputs(row, 'costol'); }
		    if (costos.has(k)) { ie.type = 'number'; }
		    cell.appendChild( ie );
		    fields.add( k );
		}

		function addupdate( clave, upd ) {
		    ups.style.visibility = 'visible';
		    let row = lista.insertRow();
		    row.dataset.clave = clave;
		    row.insertCell().appendChild( document.createTextNode(clave) );
		    row.insertCell().appendChild( document.createTextNode(upd) );
		}

		function setfields( o ) {
		    let costol = o.costol
		    let a = Object.assign({}, o, {costol: (costol/1e4).toFixed(2)});
		    Array.from(fields).filter( k => k.startsWith('prc') ).forEach( k => {a[k.replace('prc', 'precio')] = (a[k]*costol/1e4).toFixed(2)} );
		    fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = a[k] || '' } );
		    udiag.returnValue = o.clave;
		}

		admin.nuevo = function() {
		    return SQL.get({desc: 'VVV'})
			.then( JSON.parse )
			.then( a => { records.set(a[0].clave, a[0]); setfields(a[0]); udiag.showModal(); } );
		};

		admin.getRecord = function(e) {
		    let clave = e.target.parentElement.dataset.clave;
		    if (records.has(clave))
			{ setfields( cambios.has(clave) ? Object.assign({}, records.get(clave), cambios.get(clave)) : records.get(clave) ); udiag.showModal(); }
		    else {
			SQL.get({clave: clave})
			    .then( JSON.parse )
			    .then( a => { records.set(clave, a[0]); setfields(a[0]); udiag.showModal(); } );
		    }
		};

		function ppties(o) { return Object.keys(o).map( k => { return (k + '=' + o[k]); } ).join('&'); }

		function encPpties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

		admin.actualizar = function(event) {
		    let ele = tabla.querySelector("input[name=costo]");
		    return admin.anUpdate({target: {name: 'costo', value: ele.value} });
		};

		function compute(k, clave) {
		    if (costos.has(k) || k.startsWith('prc')) {
			let w = Object.assign({}, records.get(clave), cambios.get(clave));
			if (costos.has(k)) {
			    w.costol = w.costo*(100+(Number(w.impuesto)||0))*(100-(Number(w.descuento)||0));
			    let a = records.get(clave);
			    a.costol = w.costol;
			    records.set( clave, a );
			}
		        setfields( w );
		    }
		}

		admin.anUpdate = function(e) {
		    let clave = udiag.returnValue;
		    if (cambios.has( clave )) {
			let b = cambios.get( clave );
			b[e.target.name] = e.target.value;
			cambios.set( clave, b );
			lista.querySelector('tr[data-clave="'+clave+'"]').lastChild.textContent = ppties(b); // XXX Unify
		    } else {
			let a = {}; a[e.target.name] = e.target.value;
			cambios.set( clave, a );
			addupdate(clave, e.target.name+'='+e.target.value)
		    }
		    compute(e.target.name, clave);
		};

		function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }; // XXX unify

		admin.emptyCambios = () => { cambios.clear(); records.clear(); clearTable(lista); ups.style.visibility = 'hidden'; };

		function update(o) { return  XHR.get(document.location.origin + ':8081/update?' + encPpties(o) ) }

		admin.enviar = function() {
		    if (window.confirm('Estas seguro de realizar los cambios?'))
			Promise.all( Array.from(cambios.keys())
			    .map( clave => Object.assign({clave: clave, tbname: 'datos', id_tag: 'u'}, cambios.get(clave)) )
			    .map( update ) )
			.then( clave => console.log('clave: '+clave) );
			admin.emptyCambios();
		};

		XHR.getJSON('/ferre/header.lua').then( a => a.forEach( addfield ) );
	    })();

	    // SQL

	    SQL.DB = 'ferre';

	    // SET HEADER
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	// SERVER-SIDE EVENT SOURCE
	    (function() {
		function addEvents() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		}

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( addEvents, () => alert("IDBIndexed not available.") );
	    })();


	};

