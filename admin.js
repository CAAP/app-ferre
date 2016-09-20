
        "use strict";

	var admin = {};

	window.onload = function() {
	    const DBs = [ DATA ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    admin.cerrar = e => e.target.closest('dialog').close(); // XXX unify

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = clave => IDB.readDB( DATA ).get( clave );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

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

//		let add = document.location.origin + ':8081';

		function addfield( k ) {
		    let row = tabla.insertRow();
		    // label
		    row.insertCell().appendChild( document.createTextNode(k) );
		    // input
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 5; ie.name = k;
		    if (k == 'desc') { ie.size = 40; }
		    if (k == 'clave') { ie.disabled = true; }
		    row.insertCell().appendChild( ie );
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
		    fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = o[k] || '' } );
		    udiag.returnValue = o.clave;
		    udiag.showModal();
		}

		admin.getRecord = function(e) {
		    let clave = e.target.parentElement.dataset.clave;
		    if (records.has(clave))
			setfields( cambios.has(clave) ? Object.assign({}, records.get(clave), cambios.get(clave)) : records.get(clave) );
		    else {
			SQL.get({clave: clave})
			    .then( JSON.parse )
			    .then( a => { records.set(clave, a[0]); setfields(a[0]); } );
		    }
		};

		function ppties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

		admin.actualizar = function(event) {
		    let ele = tabla.querySelector("input[name=costo]");
		    return admin.anUpdate({target: {name: 'costo', value: ele.value} });
		};

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
		};

		function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }; // XXX unify

		admin.emptyCambios = () => { cambios = new Map(); records = new Map(); clearTable(lista); ups.style.visibility = 'hidden'; };

		function update(o) { return  XHR.get(document.location.origin + ':8081/update?' + ppties(o) ) }

		admin.enviar = function() {
		    if (window.confirm('Estas seguro de realizar los cambios?'))
			Promise.all( Array.from(cambios.keys())
			    .map( clave => Object.assign({clave: clave, tbname: 'datos', vwname: 'precios', id_tag: 'u'}, cambios.get(clave)) )
			    .map( update ) )
			.then( clave => console.log('clave: '+clave) );
//			.then( clave => XHR.get(document.location.origin + ':8081/update?id_tag=u&tbname=precios&clave=' + clave) );
			admin.emptyCambios();
		};

		XHR.getJSON('/ferre/header.lua').then( a => a.forEach( addfield ) );
//		UPDATES.cambios = new Map();
	    })();

//	    UPDATES.lista.style.cursor = 'pointer';

	    // SQL

	    SQL.DB = 'ferre';

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

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
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.addEventListener("update", function(e) {
			console.log("update event received.");
			DATA.update( JSON.parse(e.data) );
		    }, false);
		    esource.addEventListener("faltante", function(e) {
			console.log("faltante event received.");
			DATA.update( JSON.parse(e.data) )
			    .then( () => { let r = document.body.querySelector('tr[data-clave="'+JSON.parse(e.data)[0].clave+'"]'); if (r) { r.querySelector('.desc').classList.add('faltante'); } } );
		    }, false);
		})();


	};

