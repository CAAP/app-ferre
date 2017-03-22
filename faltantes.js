        "use strict";

	var app = {};

	window.onload = function() {
	    const PRICE = DATA.STORES.PRICE;
	    const FALT = DATA.STORES.FALT;

	    DATA.inplace = q => {let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]'); if (r) {r.classList.add('modificado');} return q;};

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    app.keyPressed = BROWSE.keyPressed;

	    app.startSearch = BROWSE.startSearch;

	    app.scroll = BROWSE.scroll;

	    //

/*
	    let mfs = [];
	    IDB.readDB( FALT ).index(  1, 'next', cursor => {
		if (cursor) {
		    mfs.push(cursor.value);
	    	    cursor.continue();
		} else { mfs.sort(); }
	    });
*/

	    app.print = () => window.open('/milista.html','lista-falts');

	    (function() {
		const bus = document.getElementById('buscar');
		const fts = document.getElementById('faltantes');
		const lfs = document.getElementById('lista-falts');
		const dps = document.getElementById('proveedores');
		const lps = document.getElementById('lista-provs');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
		const xhro = document.location.origin + ':8081/update?';

		function encPpties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

		function update(e) {
		    const tr = e.target.parentElement.parentElement;
		    const clave = tr.dataset.clave;
		    let ret = {clave: clave, tbname: (e.target.name == 'proveedor' ? 'proveedores' : 'faltantes')};
		    ret[e.target.name] = e.target.value.toUpperCase();
		    return XHR.get(xhro + encPpties(ret) );
		}

		app.remove = e => {
		    const clave = e.target.parentElement.dataset.clave;
		    if (window.confirm('Estas seguro de eliminar este articulo?'))
			XHR.get(xhro + encPpties({clave: clave, tbname: 'datos', desc: 'VVVVV'}))
			.then( () => DATA.inplace({clave: clave}) );
		};

		function isfalt(o) { return (o.faltante > 0) } // XXX == 1

		function faltnoprov(o) { return (o.faltante == 1) && !(Number(o.proveedor) || o.proveedor) }

		app.filtro = e => { BROWSE.OK = (e.target.checked ? faltnoprov : isfalt); };

		BROWSE.OK = isfalt;

		BROWSE.rows = function( a, row ) {
		    row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		    let clave = row.insertCell();
		    clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		    let desc = row.insertCell();
		    desc.classList.add('desc');
		    if (a.faltante == 2) { desc.classList.add('faltante'); } // ccs 4 PEDIDO
		    desc.appendChild( document.createTextNode( a.desc ) );
		    let costol = row.insertCell();
		    costol.classList.add('total');
		    costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
		    let obs = document.createElement('input');
		    obs.name = 'obs'; obs.value = a.obs || ''; obs.size = 12; obs.addEventListener('change', update);
		    row.insertCell().appendChild( obs );
		    let prov = document.createElement('input');
		    prov.name = 'proveedor'; prov.value = a.proveedor || ''; prov.size = 12; prov.addEventListener('change', update);
		    row.insertCell().appendChild( prov );
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.name = 'faltante'; ie.checked = (a.faltante==2); ie.value = (a.faltante == 1 ? 2 : 1); ie.addEventListener('change', update);
		    row.insertCell().appendChild( ie );
		};

	    })();

	    // HEADER
	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	// SERVER-SIDE EVENT SOURCE
	    (function() {
		function addEvents() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		    IDB.readDB( FALT ).countIndex( IDBKeyRange.only(1) ).then( q => { document.getElementById('falts-cnt').textContent = q; });
		}

    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();

	};

