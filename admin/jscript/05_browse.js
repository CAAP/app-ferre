	var BROWSE = {};

	(function() {
	    let sstr = '\uffff';
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const N = 11;

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
		    newItem(cursor.value, j); k++;
		    if (k == M) { return true; }
		    cursor.continue();
		};
	    }

	    function searchIndex(type, s, M) {
		let NN = M || N;
		let t = type.substr(0,4) == 'next';
		let range = t ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N); // XXX WHY ???? Rationale
		let j = t ? -1 : 0;
		return BROWSE.DBindex( range, type, browsing(j, NN) );
	    }

	    function searchByDesc(s) {
		console.log('Searching by description:' + s); sstr = s;
		return searchIndex('next', s).catch(e => console.log('Error searching by desc: ' + e));
	    }

	    function searchByClave(s) {
		console.log('Searching by clave:' + s);
		return BROWSE.DBget( UTILS.asnum(s) ).then(result => searchByDesc(result ? result.desc : s), e => console.log("Error searching by clave: " + e));
	    }

	    function retrieve(t) {
		let ans = BROWSE.lis;
		const pred = (t == 'prev');
		let s = ans[pred ? 'firstChild' : 'lastChild'].querySelector('.desc').textContent;

		searchIndex(t, s, 1).then(() => ans.removeChild(pred ? ans.lastChild : ans.firstChild), e => console.log('Error getting next item: ' + e));
	    }

	    BROWSE.doSearch = ss => searchByClave(ss).then( () => {BROWSE.tab.style.visibility='visible';} );

 	    BROWSE.startSearch = function startSearch(e) {
		const ss = e.target.value.toUpperCase();
		const fruit = localStorage.fruit;
		if (ss.length == 0) { console.log('Empty search: nothing to be done.'); }
		BROWSE.tab.style.visibility='hidden';
		UTILS.clearTable( BROWSE.lis );
		e.target.value = "";
	// IF string.contains('*') : searchSQL
		if (ss.includes('*'))
		    ferre.xget('query', {desc: encodeURIComponent(ss), fruit: fruit});
		else
		    BROWSE.doSearch(ss);
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

