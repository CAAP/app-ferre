        "use strict";

	var app = {};

	window.onload = function() {
	    const PROV = DATA.STORES.PROV;
	    const FALT = DATA.STORES.FALT;

	    // BROWSE

	    (function() {
		const fts = document.getElementById('faltantes');
		const lfs = document.getElementById('lista-falts');
		const dps = document.getElementById('proveedores');
		const lps = document.getElementById('lista-provs');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange; // XXX NEEDED ?

		let fsData = new Map();
/*
		function proveedores(a) {
		    let j = 0;
		    let row;
		    a.forEach( p => {
			if (j % 3 == 0) { row = lps.insertRow();}
			row.insertCell().appendChild( document.createTextNode( p ) );
			j++;
		    } );
		} */

		function loadData() {
		    let ret = [];
		    return IDB.readDB( FALT ).index(IDBKeyRange.only(1), 'next', cursor => {
			if (cursor ) { ret.push( cursor.value ); cursor.continue(); }
			else {
			    ret.forEach( a => {
				let p = a.proveedor;
				if (a.proveedor && (a.proveedor.length > 0)) {
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
				console.log(q);
				q.sort((a,b) => a.desc.localeCompare(b.desc));
			    } );
			}
		    });
		}

		function displayOne(q) {
		    let row = lfs.insertRow();
		    row.insertCell().appendChild( document.createTextNode( q.desc ) );
		    let costol = row.insertCell();
		    costol.classList.add('total');
		    costol.appendChild( document.createTextNode( (q.costol / 1e4).toFixed(2) ) );
		    row.insertCell().appendChild( document.createTextNode( q.obs ) );
		}

		app.toggleProv = e => {
		    let prov = e.target.textContent;
		    let pred = e.target.classList.toggle('activo');
		    if (pred) {
			let p = lfs.insertRow().insertCell();
			p.colSpan = 3; p.classList.toggle('activo');
			p.appendChild( document.createTextNode( prov ) );
			fsData.get( prov ).forEach( displayOne );
		    }
		};

    // LOAD DBos
		let afterLoad = () => Object.keys(DATA.STORES).forEach(store => {DATA.STORES[store].CONN = DATA.CONN});

 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( afterLoad ).then( loadData );

	    })();
	};

