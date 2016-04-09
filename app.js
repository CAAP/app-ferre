
        "use strict";

	var ferre = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' }
	};

	window.onload = function() {
	    const DATA = ferre.DATA;
	    const PEOPLE = ferre.PEOPLE;
	    const DBs = [ DATA, TICKET, PEOPLE ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // SQL

	    SQL.DB = 'ticket';

	    // TICKET

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.ttotal = document.getElementById( TICKET.ttotalID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    let id_tag = TICKET.TAGS.none;

	    ferre.add2bag = function( e ) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		return IDB.readDB( TICKET ).get( clave )
		    .then( q => { if (q) { return Promise.reject('Item is already in the bag.'); } else { return IDB.readDB( DATA ).get(clave); } } )
		    .then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } )
		    .then( TICKET.add );
	    };

	    ferre.updateItem = TICKET.update;

	    ferre.item2bin = TICKET.remove;

	    ferre.emptyBag = TICKET.empty;

	    ferre.print = function(a) {
		id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		document.getElementById('dialogo-persona').showModal();
	    };

	    // PEOPLE | SET Person Dialog

	    PEOPLE.load = function loadPEOPLE() {
		const dialog = document.getElementById('dialogo-persona');
		let ol = document.createElement('ol');
		dialog.appendChild(ol);

		function plain(obj) {
		    let ret = [];
		    for (let k in obj) { ret.push(k, obj[k]); }
		    return ('args=' + ret.join('+'));
		}

//CHECK IT'S STILL O.K.
		function sending(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    dialog.close();
		    e.target.textContent = '';
		    let objs = ['id_tag=' + id_tag, 'id_person=' + k];
		    IDB.readDB( TICKET ).count( q => { objs.count = q } );
//		    return IDB.readDB( TICKET ).count()
//			.then(q => { return {id_tag: id_tag, id_person: k, count: q} } )
//			.then( SQL.print )
//			.then( JSON.parse )
			.then( w => IDB.readDB( TICKET ).openCursor( cursor => {
		    return IDB.readDB( TICKET ).openCursor( cursor => {
			if (cursor) {
			    let o = TICKET.obj(cursor.value);
			    o.uid = w.uid;
			    objs.push( plain(o) );
			    cursor.continue();
			} else { SQL.add( objs ) } } )
		    	.then( ferre.emptyBag );
		}

		IDB.readDB( PEOPLE ).openCursor( cursor => {
		    if(cursor) {
			ol.appendChild( document.createElement('li') ).textContent = cursor.value.nombre;
			cursor.continue();
		    } else {
			let ie = document.createElement('input');
			ie.type = 'text'; ie.size = 1;
			ie.addEventListener('keydown', sending); // print | send | else
			dialog.appendChild( ie );
		    }
		})
	    };

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


// ==== BROWSING ==== //

	    (function() {

	    let sstr = '';
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const res = document.getElementById('resultados');
            const ans = document.getElementById('tabla-resultados');
	    const N = 11;

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    function newItem(a, j) {
		let row = ans.insertRow(j);
		if (a.desc.startsWith(sstr)) { row.classList.add('encontrado'); };
		row.dataset.clave = a.clave;
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		row.insertCell().appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		row.insertCell().appendChild( document.createTextNode( a.precio1.toFixed(2) ) );
		row.insertCell().appendChild( document.createTextNode( a.u1 ) );
	    }

	    function browsing(j, M) {
		let k = 0;
		return function(cursor) {
		    if (k == M || !cursor) { return true; }
		    newItem(cursor.value, j);
		    k++; cursor.continue();
		};
	    }

	    function searchIndex(k, type, s, M) {
		let NN = M || N;
		let t = type.substr(0,4) == 'next';
		let range = t ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N);
		let j = t ? -1 : 0;
		return IDB.readDB( k ).index( range, type, browsing(j, NN) );
	    }

	    function searchByDesc(s) {
		console.log('Searching by description:' + s); sstr = s;
		return searchIndex(DATA, 'next', s);
	    }

	    function searchByClave(s) {
		console.log('Searching by clave:' + s);
		return IDB.readDB( DATA ).get( asnum(s) ).then(result => searchByDesc(result ? result.desc : s), e => console.log("Error searching by clave: " + e));
	    }

	    function startSearch(e) {
		if (e.target.value.length == 0) { console.log('Empty search: nothing to be done.'); }
		res.style.visibility='visible';
		clearTable( ans );
		searchByClave(e.target.value.toUpperCase());
		e.target.value = ""; // clean input field
	    }

	    function retrieve(t) {
		let s = ans[(t == 'prev') ? 'firstChild' : 'lastChild'].querySelector('.desc').textContent;
		searchIndex(DATA, t, s, 1).then( () => ans.removeChild((t == 'prev') ? ans.lastChild : ans.firstChild ));
	    }

 	    ferre.startSearch = startSearch;

	    ferre.keyPressed = function keyPressed(e) {
		switch (e.key || e.which) {
		    case 'Escape':
		    case 'Esc':
		    case 27:
			e.target.value = "";
			break;
		    default: break;
		}
	    };

	    ferre.scroll = function scroll(e) {
		if (e.deltaY > 0)
		    retrieve('next');
		else
		    retrieve('prev');
	    };

	    })();

	};

