
    "use strict";

    var UPDATES = { VERSION: 1, DB: 'updates', STORE: 'updates-clave',  KEY: 'clave' };

    (function() {
//	    const nums = new Set(['descuento', 'impuesto', 'costo', 'p1', 'p2', 'p3']);
	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function ppties(o) { return Object.keys(o).map( k => { return (k + '=' + o[k]); } ).join(); }

	    function newUpdate( q ) {
		let ups = UPDATES.ups;
		(ups.classList.contains('visible') || (ups.style.visibility = 'visible'));
		let row = UPDATES.lista.insertRow();
		row.classList.add('basura');
		row.insertCell().appendChild( document.createTextNode(q.clave) );
		row.insertCell().appendChild( document.createTextNode(q.desc) );
		row.insertCell().appendChild( document.createTextNode( ppties(q.actions) ) );
	    }

	    function editUp( w ) { UPDATES.lista.lastChild.lastChild.textContent = ppties( w.actions ); }

	    function toggleUpdates() {
		let ups = UPDATES.ups;
		if (ups.classList.toggle('visible'))
		    ups.style.visibility = 'visible';
		else
		    ups.style.visibility = 'hidden';
	    }

	    function fillVal( k, v ) {
		let ie = UPDATES.tabla.querySelector('input[name='+k+']');
		if (ie) { ie.value = v; }
	    }

	    function clearTable() {
		let tb = UPDATES.lista; while (tb.firstChild) { tb.removeChild( tb.firstChild ); }
	    }

	    UPDATES.load = function() {
		let objStore = IDB.readDB( UPDATES );
		objStore.count().then( result => {
		    if (!(result>0)) { return; }
		    toggleUpdates();
		    return objStore.openCursor( cursor => {
			if (cursor) {
			    newUpdate( cursor.value );
		    	    cursor.continue();
			}
		    });
		});
	    };

	    UPDATES.getRecord = function( clave ) {
		return SQL.get( {clave: clave} )
		    .then( JSON.parse )
		    .then( a => { let q = a[0]; for (let k in q) { fillVal(k, q[k]); }; return q; } )
		    .then( q => { UPDATES.tabla.dataset.clave = q.clave; UPDATES.tabla.dataset.desc = q.desc.substr(0, 20) + ' ...'; } )
		    .then( () => IDB.readDB( UPDATES).get( clave ) )
		    .then( w => { if (w) { for (let k in w.actions) { fillVal(k, w.actions[k]); } } } )
		    .then( () => UPDATES.diag.showModal() );
	    };

	    UPDATES.anUpdate = function( nam, val ) {
		let clave = UPDATES.tabla.dataset.clave;
		let desc = UPDATES.tabla.dataset.desc;
		let objs = IDB.write2DB( UPDATES );
		return objs.get( clave ).then( w => {
		    if (w) {
			w.actions[nam] = val;
			return objs.put(w).then( editUp );
		    } else {
			let y = {clave: clave, desc: desc, actions: {}};
			y.actions[nam] = val;
			IDB.write2DB( UPDATES ).put( y ).then( newUpdate );
		    }
		});
	    };

	    UPDATES.remove = function( tr ) {
		let clave = tr.firstChild.textContent;
		let objStore = IDB.write2DB( UPDATES )
		return objStore.delete( clave ).then( () => {
		    UPDATES.lista.removeChild( tr );
		    if (!UPDATES.lista.hasChildNodes()) { toggleUpdates(); }
		});
	    };

	    UPDATES.emptyBag = () => IDB.write2DB( UPDATES ).clear().then( () => { clearTable(); toggleUpdates(); } );

    })();
