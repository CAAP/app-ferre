        "use strict";

	var admin = {};

	window.onload = function() {
	    const PRICE = DATA.STORES.PRICE;

	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {DATA.clearTable(r); BROWSE.rows(q,r); r.classList.add('modificado');} return q;};

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = clave => IDB.readDB( PRICE ).get( clave );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f ); // XXX readDB proveedores HERE

	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let costol = row.insertCell();
		costol.classList.add('total'); costol.classList.add('precio1');
		costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
	    };

	    admin.startSearch = BROWSE.startSearch;

	    admin.keyPressed = BROWSE.keyPressed;

	    admin.scroll = BROWSE.scroll;

	    admin.guardar = function temporal(s) {
		let ret = [];
		IDB.readDB( PRICE ).openCursor(cursor => {
		if (cursor) {
		    let a = cursor.value;
		    ret.push( a.desc + '\t' + (a.costol / 1e4).toFixed(2) );
		    cursor.continue();
		} else {
		    let b = new Blob([ret.join('\n')], {type: 'text/html'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'ListaPrecios.tsv'
		    a.click();
		    URL.revokeObjectURL(url);
		} });
	    };


	    // UPDATES

	    // cambios dialog - lista de cambios
	    (function() {
		let tabla = document.getElementById('tabla-cambios'); // tabla inside dialog
		let udiag = document.getElementById('dialogo-cambios');

		let fields = new Set();
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

		function setfields( o ) {
		    let costol = o.costol
		    let a = Object.assign({}, o, {costol: (costol/1e4).toFixed(2)});
		    Array.from(fields).filter( k => k.startsWith('prc') ).forEach( k => {a[k.replace('prc', 'precio')] = (a[k]*costol/1e4).toFixed(2)} );
		    fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = a[k] || '' } );
		    udiag.returnValue = o.clave;
		}

		admin.nuevo = function() {
		    return XHR.getJSON('/admin/get.lua?desc=VVV')
			.then( a => {
			    let clave = a[0].clave.toString();
			    console.log(a[0]);
			    let o = {clave: clave, costo: 0, costol: 0, prc1: 0, prc2: 0, prc3: 0};
			    CHANGES.rawset(clave, () => o);
			    setfields(o);
			    udiag.showModal();
			} );
		};

		admin.getRecord = function(e) {
		    let clave = e.target.parentElement.dataset.clave;
		    CHANGES.fetch(clave, '/admin/get.lua?clave='+clave, setfields);
		    udiag.showModal();
		    tabla.querySelectorAll('.modificado').forEach(o => o.classList.remove('modificado'));
		    CHANGES.inplace( clave, p => tabla.querySelector("input[name="+p+"]").classList.add('modificado') );
		};

		admin.actualizar = function() {
		    let ele = tabla.querySelector("input[name=costo]");
		    return admin.anUpdate({target: ele});
		};

		admin.cancelar = { CHANGES.clear(); udiag.close(); };

		function costol(o) {o.costol = o.costo*(100+(Number(o.impuesto)||0))*(100-(Number(o.descuento)||0));}

		function compute(clave, k) {
		    if (k.startsWith('prc'))
			CHANGES.fetch(clave, '', setfields);
		    else
			CHANGES.fetch( clave, '', w => { costol(w); CHANGES.rawset(clave, o => Object.assign(o, {costol: w.costol})); setfields(w); } );
		}

		admin.anUpdate = function(e) {
		    let clave = udiag.returnValue;
		    let k = e.target.name;
		    let v = e.target.value;
		    CHANGES.update(clave, k, v);
		    if (costos.has(k)) { compute(clave, k); }
		    e.target.classList.add('modificado');
		};

		function update(o) { return  XHR.get(document.location.origin + ':8081/update?' + DATA.encPpties(Object.assign(o,{tbname: 'datos'}))) }

		admin.enviar = function() {
		    let clave = udiag.returnValue;
		    if (window.confirm('Estas seguro de realizar los cambios?'))
			CHANGES.fetch(clave, '', update)
			.then( () => { udiag.close(); CHANGES.clear(); } );
		};

		XHR.getJSON('/admin/header.lua').then( a => a.forEach( addfield ) );
	    })();

	    // SET HEADER
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;'; })();

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
