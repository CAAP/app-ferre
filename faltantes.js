        "use strict";

	var app = { VERSION: 1,
		DB: 'faltantes',
		STORE: 'faltantes-desc',
		KEY: 'desc',
		INDEX: 'proveedor',
		FILE: '/ferre/faltantes.lua'
	 };

	window.onload = function() {
	    const DBs = [ app ]; // , TICKET

	    // Resultados

	    (function() {

		const tab = document.getElementById('resultados');
		const lis = document.getElementById('tabla-resultados');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

		app.reload = () => IDB.clearDB( app ).then(() => IDB.populateDB(app) ).then( app.load );

		app.guardar = () => {
		    let ret = [];
		    IDB.readDB( app ).openCursor( cursor =>  {
			if (cursor) {
			    let o = cursor.value;
			    ret.push( 'args=clave+'+o.clave+'+proveedor+'+o.proveedor );
			    cursor.continue();
			} else { XHR.get( '/ferre/proveedor.lua?' + ret.join('&') ); }
		    } );
		};

		let update = e => {
		    let tr = e.target.parentElement.parentElement;
		    let desc = tr.querySelector('.desc').textContent;
		    let objStore = IDB.write2DB( app );
		    return objStore.get( desc ).then( q => {
			if (q) { q.proveedor = e.target.value; q.proveedor = e.target.value; return q; }
			else { Promise.fail('No key found!'); }
		    }, e => console.log("Error searching by desc: " + e)  )
		    .then( objStore.put );
		};

		function displayItem( a ) {
		    let row = lis.insertRow();
		    row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		    let clave = row.insertCell();
		    clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		    let desc = row.insertCell();
		    desc.classList.add('desc');
		    desc.appendChild( document.createTextNode( a.desc ) );
		    row.insertCell().appendChild( document.createTextNode( a.costol ) );
		    let obs = a.obs ? a.obs.join(', ') : '';
		    row.insertCell().appendChild( document.createTextNode( obs ) );
		    let ie = document.createElement('input'); ie.value = a.proveedor || ''; ie.size = 8; ie.addEventListener('change', update);
		    row.insertCell().appendChild( ie );
		};

		function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

		function load(s) {
		    clearTable(lis);
		    let objStore = IDB.readDB( app );
		    objStore.count().then( result => {
			if (!(result>0)) { return; }
			return objStore.index( IDBKeyRange.upperBound(s, false), 'prev', cursor => {
			    if (cursor) {
				displayItem( cursor.value );
		    		cursor.continue();
			    }
			} );
		    });
		};

		app.load = () => load('X');

		app.done = () => load('V');
	    })();


	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // HEADER

	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	};

