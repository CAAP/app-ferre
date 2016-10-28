        "use strict";

	var app = { VERSION: 1,
		DB: 'faltantes',
		STORE: 'faltantes-clave',
		KEY: 'clave',
		INDEX: ['provdesc'],
		FILE: '/ferre/faltantes.lua',
		MAP: function(q) {
		    q.provdesc = q.proveedor + '|' + q.desc.sub(1,10);
		    return q;
		}
	 };

	window.onload = function() {
	    const DBs = [ app ]; // , TICKET

	    // Resultados

	    (function() {

		const tab = document.getElementById('resultados');
		const lis = document.getElementById('tabla-resultados');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

		app.reload = () => IDB.clearDB( app ).then(() => IDB.populateDB(app) ).then( app.load );

		let pages = '<html><body><table><tbody>$BODY</tbody></table></body></html>'

		let ans = '';

		function generar() {
		    let ret = [];
		    return IDB.readDB( app ).index( IDBKeyRange.upperBound('V', false), 'prev', cursor =>  {
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
/*

		function slice(a) {
		    let third = a.length / 3;
		    XHR.get('/ferre/proveedor.lua?'+ a.slice(0,third).join('&')).then( () => XHR.get('/ferre/proveedor.lua?'+ a.slice(third, 2*third).join('&')) ).then( () => XHR.get('/ferre/proveedor.lua?'+ a.slice(2*third).join('&')) );
		}

		app.guardar = () => {
		    let ret = [];
		    IDB.readDB( app ).openCursor( cursor =>  {
			if (cursor) {
			    let o = cursor.value;
			    if (!(o.proveedor.startsWith('X') || o.proveedor.length == 0))
			        ret.push( 'args=clave+'+o.clave+'+proveedor+'+o.proveedor );
			    cursor.continue();
			} else { slice(ret); }//XHR.get( '/ferre/proveedor.lua?' + ret.join('&') ); }
		    } );
		};
*/

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

		let update = e => {
		    const tr = e.target.parentElement.parentElement;
		    const clave = asnum( tr.dataset.clave );
		    const prove = e.target.value;

		    let objStore = IDB.write2DB( app );
		    return XHR.get('/ferre/proveedor.lua?clave='+clave+'&proveedor='+prove)
			.then( () => objStore.get( clave ) )
			.then( q => { if (q) { q.proveedor = prove; q.provdesc = q.proveedor + '|' + q.desc.sub(1,10); return q; } } )
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

		function load(s) {
		    clearTable(lis);
		    let objStore = IDB.readDB( app );
		    objStore.count().then( result => {
			if (!(result>0)) { return; }
			return objStore.index( IDBKeyRange.upperBound(s, false), 'next', cursor => {
			    if (cursor) {
				displayItem( cursor.value );
		    		cursor.continue();
			    }
			} );
		    });
		};

		app.load = () => load('X');

		app.done = () => load('A');
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

