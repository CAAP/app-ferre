        "use strict";

	var app = {};

	window.onload = function() {

	    const FALT = DATA.STORES.FALT;

	    // Resultados

	    (function() {
		const tab = document.getElementById('resultados');
		const lis = document.getElementById('tabla-resultados');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

//		app.reload = () => IDB.clearDB( app ).then(() => IDB.populateDB(app) ).then( app.load );

		let pages = '<html><body><table><tbody>$BODY</tbody></table></body></html>'

		let ans = '';

		function generar() {
		    let ret = [];
		    return IDB.readDB( FALT ).index( IDBKeyRange.upperBound('V', false), 'prev', cursor =>  {
			if (cursor) {
			    let o = cursor.value;
			    if (!(o.proveedor.startsWith('Z') || o.proveedor.length == 0))
			        ret.push( '<tr><td>'+o.desc+'</td><td align="right">'+o.costol+'</td><td align="center">'+(o.obs||'')+'</td></tr>' );
			    cursor.continue();
			} else { ans = pages.replace('$BODY', ret.join('')); }
		    } );
		}

		app.print = function() {
		    return new Promise((resolve, reject) => {
			let iframe = document.createElement('iframe');
			iframe.style.visibility = "hidden";
			iframe.width = 400;
			document.body.appendChild(iframe);
			iframe.onload = resolve(iframe.contentWindow);
		    } )
			.then( win => generar().then( () => { return win } ) )
			.then( win => { let doc = win.document; doc.open(); doc.write(ans); doc.close(); return win } )
			.then( win => win.print() )
			.then( () => document.body.removeChild(document.body.lastChild) );
		};

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

		let update = e => {
		    const tr = e.target.parentElement.parentElement;
		    const clave = asnum( tr.dataset.clave );
		    const prove = e.target.value;

		    let objStore = IDB.write2DB( FALT );
// XXX Change this to stream (8081)
		    return XHR.get('/ferre/proveedor.lua?clave='+clave+'&proveedor='+prove)
			.then( () => objStore.get( clave ) )
			.then( q => { if (q) { q.proveedor = prove; return q; } } )
			.then( objStore.put );
		};

		function displayItem( a ) {
		    let row = lis.insertRow();
		    row.dataset.clave = a.clave;
		    row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		    let clave = row.insertCell();
		    clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		    let desc = row.insertCell();
		    desc.classList.add('desc');
		    desc.appendChild( document.createTextNode( a.desc ) );
		    row.insertCell().appendChild( document.createTextNode( a.costol ) );
		    let obs = a.obs || '';
		    row.insertCell().appendChild( document.createTextNode( obs ) );
		    let ie = document.createElement('input'); ie.value = a.proveedor || ''; ie.size = 8; ie.addEventListener('change', update);
		    row.insertCell().appendChild( ie );
		};

		function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

		function load() {
		    clearTable(lis);
		    let falts = []
		    return IDB.readDB( FALT ).index( IDBKeyRange.lowerBound([0,'A','A'], true), 'next', cursor => {
			if (cursor) { displayItem( cursor.value ); cursor.continue(); }
		    } );
		};

		app.load = load;

//		load();

//		app.load = () => load('X');

//		app.done = () => load('A');
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
		    app.load();
		}

    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();

	};

