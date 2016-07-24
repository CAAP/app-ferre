// ==== BROWSING ==== //

	"use strict";

	var BROWSE = {};

	(function() {

	    let sstr = '';
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const N = 11;

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    function newItem(a, j) {
		let row = BROWSE.lis.insertRow(j);
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

	    function searchIndex(type, s, M) {
		let NN = M || N;
		let t = type.substr(0,4) == 'next';
		let range = t ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N);
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
		let s = ans[(t == 'prev') ? 'firstChild' : 'lastChild'].querySelector('.desc').textContent;
		searchIndex(t, s, 1).then( () => ans.removeChild((t == 'prev') ? ans.lastChild : ans.firstChild ));
	    }

 	    BROWSE.startSearch = function startSearch(e) {
		if (e.target.value.length == 0) { console.log('Empty search: nothing to be done.'); }
		BROWSE.tab.style.visibility='visible';
		clearTable( BROWSE.lis );
	// IF string.contains('*') : searchSQL
		searchByClave(e.target.value.toUpperCase());
		e.target.value = ""; // clean input field
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

