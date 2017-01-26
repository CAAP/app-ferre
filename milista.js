        "use strict";

	var app = {};

	window.onload = function() {
	    const PROV = DATA.STORES.PROV;
	    const FALT = DATA.STORES.FALT;

	    // BROWSE

	    (function() {
		const lfs = document.getElementById('lista-falts');
		const lps = document.getElementById('lista-provs');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange; // XXX NEEDED ?

		let fsData = new Map();

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

		function loadData() {
		    let ret = [];
		    return IDB.readDB( FALT ).index(IDBKeyRange.only(1), 'next', cursor => {
			if (cursor ) { ret.push( cursor.value ); cursor.continue(); }
			else {
			    ret.forEach( a => {
				let p = asnum(a.proveedor);
				if (p) {
				    if (fsData.has( p )) { fsData.get( p ).push( a ); }
				    else { fsData.set( p, [a] ); }
				}
			    } );
			    let j = 0;
			    let row;
			    fsData.forEach( (q,p) => {
				if (j % 3 == 0) { row = lps.insertRow();}
				row.insertCell().appendChild( document.createTextNode( p ) );
				j++;
				q.sort((a,b) => a.desc.localeCompare(b.desc));
			    } );
			}
		    });
		}

		const xhro = document.location.origin + ':8081/update?';

		function encPpties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

		let pedido = e => XHR.get( xhro + encPpties({clave: e.target.value, tbname: 'faltantes', faltante: 2}) ).then( () => { let tr = e.target.parentElement.parentElement; tr.parentElement.removeChild( tr ); });

		let proveedor = e => XHR.get( xhro + encPpties({clave: e.target.name, tbname: 'proveedores', proveedor: e.target.value})).then( () => e.target.parentElement.parentElement.classList.add('modificado') );

		function displayOne(q) {
		    let row = lfs.insertRow();
		    row.insertCell().appendChild( document.createTextNode( q.desc ) );
		    let costol = row.insertCell();
		    costol.classList.add('total');
		    costol.appendChild( document.createTextNode( (q.costol / 1e4).toFixed(2) ) );
		    row.insertCell().appendChild( document.createTextNode( q.obs ) );

		    let prov = row.insertCell();
		    prov.classList.add('no-print');
		    let ie = document.createElement('input');
		    ie.name = q.clave; ie.value = q.proveedor; ie.addEventListener('change', proveedor);
		    prov.appendChild( ie );
		    let pred = row.insertCell();
		    pred.classList.add('no-print');
		    let ck = document.createElement('input');
		    ck.type = 'checkbox'; ck.value = q.clave; ck.addEventListener('change', pedido);
		    pred.appendChild( ck );
		}

		app.save = function temporal(s) {
		    let ret = Array.from(lfs.children).map(row => Array.from(row.children).map(x => x.textContent).join('\t'));
		    let b = new Blob([ret.join('\n')], {type: 'text/html'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'ListaFaltantes.tsv'
		    a.click();
		    URL.revokeObjectURL(url);
		};

		app.toggleProv = e => {
		    let prov = asnum(e.target.textContent);
		    let pred = e.target.classList.toggle('activo');
		    if (pred) {
			let p = lfs.insertRow().insertCell();
			p.colSpan = 3; p.classList.toggle('activo');
			p.appendChild( document.createTextNode( prov ) );
			fsData.get( prov ).forEach( displayOne );
		    }
		};

		app.reset = () => {DATA.clearTable(lfs); DATA.clearTable(lps); fsData.clear(); loadData();};

    // LOAD DBos
		let afterLoad = () => Object.keys(DATA.STORES).forEach(store => {DATA.STORES[store].CONN = DATA.CONN});

 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( afterLoad ).then( loadData );

	    })();
	};

