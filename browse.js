// ==== BROWSING ==== //

	"use strict";

	var BROWSE = {};

	(function() {

	    let sstr = '\uffff';
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const N = 11;

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }

	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let precios = a.precios;
		Object.keys( precios ).forEach( k => {
		    let pesos = row.insertCell();
		    pesos.classList.add('total'); pesos.appendChild( document.createTextNode( precios[k] ) );
		    if (k == 'precio1') { pesos.classList.add(k); }
		} );
	    };

	    function newItem(a, j) {
		let row = BROWSE.lis.insertRow(j);
//		row.title = a.desc.substr(0,3); // TRYING OUT LOCATION XXX
		if (a.desc.startsWith(sstr)) { row.classList.add('encontrado'); };
		row.dataset.clave = a.clave;
		// insert rows
		BROWSE.rows(a, row);
	    }

	    function browsing(j, M) {
		let k = 0;
		return function(cursor) {
		    if (!cursor) { return Promise.reject('Not suitable value found!'); } // XXX STILL necessary ????
		    if (k == M) { return true; }
		    if (BROWSE.OK(cursor.value)) { newItem(cursor.value, j); k++; }
		    cursor.continue();
		};
	    }

	    BROWSE.OK = x => true;

	    function searchIndex(type, s, M) {
		let NN = M || N;
		let t = type.substr(0,4) == 'next';
		let range = t ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N); // XXX WHY ???? Rationale
		let j = t ? -1 : 0;
		return BROWSE.DBindex( range, type, browsing(j, NN) );
	    }

	    function searchByDesc(s) {
		console.log('Searching by description:' + s); sstr = s;
		return searchIndex('next', s);
	    }

	    function searchByClave(s) {
		console.log('Searching by clave:' + s);
		return BROWSE.DBget( asnum(s) ).then(result => searchByDesc(result ? result.desc : s), e => console.log("Error searching by clave: " + e));
	    }

	    function retrieve(t) {
		let ans = BROWSE.lis;
		const pred = (t == 'prev');
		let s = ans[pred ? 'firstChild' : 'lastChild'].querySelector('.desc').textContent; //let s = BROWSE.fetchBy(ans, t);

		let range = pred ? IDBKeyRange.upperBound(s, true) : IDBKeyRange.lowerBound(s, true);
		let j = pred ? 0 : -1;
		BROWSE.DBindex( range, t, cursor => {
		    if (!cursor) { return false; }
		    if (BROWSE.OK(cursor.value)) { newItem(cursor.value, j); ans.removeChild(pred ? ans.lastChild : ans.firstChild ); return true; }
		    cursor.continue();
		} );
	    }

 	    BROWSE.startSearch = function startSearch(e) {
		const ss = e.target.value.toUpperCase();
		if (ss.length == 0) { console.log('Empty search: nothing to be done.'); }
		BROWSE.tab.style.visibility='hidden';
		clearTable( BROWSE.lis );
		e.target.value = "";
		e.target.blur();
	// IF string.contains('*') : searchSQL
		if (ss.includes('*')) {
		    XHR.getJSON('/ferre/query.lua?desc='+encodeURIComponent(ss))
			.then( a => {
			    if (a[0])
				searchByDesc(a[0].desc.match(ss.replace('*','.+'))[0]).then( () => {BROWSE.tab.style.visibility='visible';} );
			} );
		} else { searchByClave(ss).then( () => {BROWSE.tab.style.visibility='visible';} ); }
	    };

	    BROWSE.keyPressed = function keyPressed(e) {
		switch (e.key || e.which) {
		    case 'Escape':
		    case 'Esc':
		    case 27:
			e.target.value = "";
			break;
		    default: break;
		}
	    };

	    BROWSE.scroll = function scroll(e) {
		if (e.deltaY > 0)
		    retrieve('next');
		else
		    retrieve('prev');
	    };

	})();

