        "use strict";

	var app = {};

	window.onload = function() {
	    const PRICE = DATA.STORES.PRICE;
	    const FALT = DATA.STORES.FALT;

//	    DATA.inplace = q => Promise.resolve(q);
	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = clave => IDB.readDB( PRICE ).get( clave );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( FALT ).index( a, b, f );

	    app.scroll = BROWSE.scroll;

	    (function() {
		const tab = document.getElementById('resultados');
		const lis = document.getElementById('tabla-resultados');
		const flbl = document.getElementById('falts');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

		let pages = '<html><body><table><tbody>$BODY</tbody></table></body></html>'
		let ans = '';
		let falts = 0;

	    	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function encPpties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

	    DATA.inplace = q => {
		let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]');
		if (q.faltante && q.faltante != 1) { flbl.textContent = --falts; return q; } // r.parentElement.removeChild(r);  BROWSE.appendOne().then(() => 
		if (r) {DATA.clearTable(r); BROWSE.rows(q,r);}
		return q;
	    };

		BROWSE.fetchBy = tr => [1, tr.querySelector('input[name="prov"]').value, tr.querySelector('.desc').textContent];

		let update = e => {
		    const tr = e.target.parentElement.parentElement;
		    const clave = asnum( tr.dataset.clave );
		    const prove = e.target.value.toUpperCase();
		    return XHR.get(document.location.origin + ':8081/update?' + encPpties({clave: clave, tbname: 'proveedores', proveedor: prove}) );
		};

		let pedido = e => XHR.get(document.location.origin + ':8081/update?' + encPpties({clave: e.target.value, tbname: 'faltantes', faltante: 2}));
/*{
//		    const tr = e.target.parentElement.parentElement;
		    return XHR.get(document.location.origin + ':8081/update?' + encPpties({clave: e.target.value, tbname: 'faltantes', faltante: 2}));
		}; */

		BROWSE.rows = function( a, row ) {
		    row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		    let clave = row.insertCell();
		    clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		    let desc = row.insertCell();
		    desc.classList.add('desc');
		    desc.appendChild( document.createTextNode( a.desc ) );
		    let costol = row.insertCell();
		    costol.classList.add('total');
		    costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
		    let obs = a.obs || '';
		    row.insertCell().appendChild( document.createTextNode( obs ) );
		    let prov = document.createElement('input');
		    prov.name = 'prov'; prov.value = a.proveedor || ''; prov.size = 12; prov.addEventListener('change', update);
		    row.insertCell().appendChild( prov );
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = a.clave; ie.addEventListener('change', pedido);
		    row.insertCell().appendChild( ie );
		};

		function load() {
		    const fkey = IDBKeyRange.bound([1,'9','9'], [1,'a','a'], false, false);
		    return IDB.readDB( FALT ).countIndex(fkey).then( n => {falts = n; flbl.textContent = n;} )
			.then(() => BROWSE.searchIndex('next', [1,'9','9']));
		};

		app.load = load;
	    })();


/*		function generar() {
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
		}; */

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

