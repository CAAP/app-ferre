        "use strict";

	var app = {};

	window.onload = function() {
	    const PRICE = DATA.STORES.PRICE;
	    const FALT = DATA.STORES.FALT;

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );

	    app.keyPressed = BROWSE.keyPressed;

	    app.startSearch = BROWSE.startSearch;

	    app.scroll = BROWSE.scroll;

	    // Efficient LOOK UP
	    (function() {
		let mfs; // will be rewritten
		let all; // = [];
		let N = 0;
		let provs; //= new Map();
		let selection;
		let tmp; // = [];
		let nopedido; // = [];
		const cnt = document.getElementById('falts-cnt');
		const lista = document.getElementById('lista-provs');
		const diagp = document.getElementById('proveedores');
		const scnt = document.getElementById('sel-count');
		const ckbox = document.querySelector('input[name=pedido]');
		const reload = document.getElementById('recargar');
		const alpha = /\w/;

		function sortDescAlpha(a,b) { return +(a.desc > b.desc) || +(a.desc === b.desc) - 1; }
//		let sortDescAlpha = (a,b) => a.desc.localeCompare(b.desc);

		function groupByProv( o ) {
		    let p = o.proveedor || '';
		    p = alpha.test(p) ? p.toString() : '000';
		    if (provs.has(p))
			provs.get(p).push(o.clave);
		    else
			provs.set(p, [o.clave]);
		}

		function findDesc(s) { return mfs.findIndex(o => { return (o.desc >= s) }) }

// Cuold be done more efficient by using retrieve from browse.js from in-memory array

		function iter(j, b, f, o) {
		    let k = j;
		    const d = b ? 1 : -1;
		    function getNext() {
			const i = k+d;
			if ((i >= 0)&&(i < N)) {
			    k = i;
			    o.value = mfs[i];
			    return f(o);
			} else { return f(); }
		    }
		   return getNext;
		}

		function getCursor(a, b, f) {
		    let pred = (b != 'prev'); // lower := next -> true
		    let j = findDesc( a.lower || a.upper );
		    if (j === -1) { return Promise.reject('Nothing found!'); }
		    let o = {value: mfs[j]};
		    o.continue = iter(j, pred, f, o);
		    if (a.lower ? a.lowerOpen : a.upperOpen) { return Promise.resolve( o.continue() ); } // FALSE by default; TRUE -> not include self
		    return Promise.resolve( f(o) );
		}

		function rewind() { if (mfs.length) { return BROWSE.startSearch({target: {value: mfs[0].desc}}); } }

		function addProvs() {
		    let ret = [];
		    DATA.clearTable(lista);
		    provs.forEach((a,p) => ret.push({desc: p, n: a.length})); // do i still need length?? XXX
		    ret.sort(sortDescAlpha);
		    let row = lista.insertRow();
		    ret.forEach((o,i) => {
			if (i%10 == 0) { row = lista.insertRow(); }
			row.insertCell().appendChild( document.createTextNode(o.desc) ); //  add o.n as in element.title = o.n  XXX
		    });
		}

		function setCount() {
		    mfs = (ckbox.checked ? tmp : nopedido);
		    N = mfs.length;
		    cnt.textContent = N;
		}

		function reset() {
		    nopedido = tmp.filter(o => { return (o.faltante === 1); });
		    setCount();
	 	}

		function getProvs() {
		    let selected = Array.from(lista.querySelectorAll('.activo'));
		    if (!selected.length)
			tmp = all.slice(); // DO NOTHING!!!
		    else {
			selected = new Set( selected.map(o => provs.get(o.textContent)).reduce((a,o) => a.concat(o)) );
			tmp = all.filter(o => selected.has(o.clave));
//			tmp.sort(sortDescAlpha); // necessary???  XXX
		    }
		    reset();
		    rewind();
		}

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }; // UNIFY XXX

		let loadFalts = () => IDB.readDB( FALT ).index(  IDBKeyRange.lowerBound(1), 'next', cursor => {
		    if (cursor) {
			all.push(cursor.value);
	    		cursor.continue();
		    } else {
			reload.style.visibility = 'hidden';
		        provs = new Map();
			selection = new Set();
			scnt.textContent = 0;
			all.sort(sortDescAlpha);
			all.forEach( groupByProv );
			addProvs();
			tmp = all.slice();
			reset();
			rewind();
		    }
		});

		app.getGroups = function() {
		    let gps = Array.from(lista.querySelectorAll('.activo'));
		    if (!gps.length) { return false; } // DO NOTHING
		    else {
			let selected = new Map( mfs.map( o => [o.clave, o] ) ); // Maybe do it for mfs always XXX
			gps = gps.map(o => provs.get(o.textContent)).reduce((a,o) => a.concat(o)).filter(k => selected.has(k)).map(k => selected.get(k));
			return gps;
		    }
		};

		app.selectme = e => {
		    const clave = asnum( e.target.textContent );
		    const pred = !selection.has(clave);
		    e.target.classList.toggle('gold', pred);
		    scnt.textContent = parseInt(scnt.textContent) + (pred ? 1 : -1);
		    if (pred) { selection.add( clave ); } else { selection.delete( clave ); }
		};

		app.getSelection = () => {
		    tmp = all.filter(o => selection.has(o.clave));
		    tmp.forEach( o => { o.selected = true } );
		    reset();
		    rewind();
		};

		app.pedido = () => { setCount(); rewind(); };

		app.toggleProv= e => e.target.classList.toggle('activo');

		app.doProvs = () => { if (diagp.style.display === '') { diagp.style.display = 'block'; } else { diagp.style.display = ''; getProvs(); } };

		app.onLoaded = () => { all = []; return loadFalts(); };

		app.clearProvs = () => lista.querySelectorAll('.activo').forEach(o => o.classList.toggle('activo'));

		BROWSE.DBindex = getCursor;

		DATA.inplace = q => {
		    let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]');
		    if (r) { r.classList.add('modificado'); }
		    reload.style.visibility = 'visible';
		    return q;
		};

	    })();

/*/		app.save = function temporal(s) {
		    let ret = Array.from(lfs.children).map(row => Array.from(row.children).map(x => x.textContent).join('\t'));
		    let b = new Blob([ret.join('\n')], {type: 'text/html'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'ListaFaltantes.tsv'
		    a.click();
		    URL.revokeObjectURL(url);
		}; */

		// // // //

	    (function() {
		const body = document.body;
		let TXT = ['<html><head><link rel="stylesheet" href="public/app.css" media="print"></head>',
			'<body><table><tbody>',
			'',
			'</tbody></table></body></html>'];
		let ps;

		function asrow( o ) {
		    let ret = '';
		    const prov = o.proveedor;
		    if (!ps.has(prov)) { ps.add(prov); ret = '<tr><td colspan="3" class="activo">'+o.proveedor+'</td></tr>'; }
		    ret += '<tr><td>'+o.desc+'</td><td>'+(o.costol/1e4).toFixed(2)+'</td><td>'+o.obs+'</td></tr>';
		    return ret;
		}

		function newiframe() {
		    return new Promise( (resolve, reject) => {
			let iframe = document.createElement('iframe');
			iframe.style.visibility = "hidden";
			iframe.width = 400;
			body.appendChild( iframe );
			iframe.onload = resolve(iframe.contentWindow);
		    });
		}

		app.print = () => {
		    ps = new Set();
		    TXT[3] = app.getGroups().map( asrow ).join('\n');
		    return newiframe()
			.then( win => { let doc = win.document; doc.open(); doc.write(TXT.join('\n')); doc.close(); return win} )
			.then( win => win.print() )
			.then( () => body.removeChild(body.lastChild) );
		};

	    })();

		////////

	    (function() {
		const bus = document.getElementById('buscar');
		const fts = document.getElementById('faltantes');
		const lfs = document.getElementById('lista-falts');
		const dps = document.getElementById('proveedores');
		const lps = document.getElementById('lista-provs');
		const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
		const xhro = document.location.origin + ':8081/update?';

		function encPpties(o) { return Object.keys(o).map( k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'); }

		function update(e) {
		    const tr = e.target.parentElement.parentElement;
		    const clave = tr.dataset.clave;
		    let ret = {clave: clave, tbname: (e.target.name == 'proveedor' ? 'proveedores' : 'faltantes')};
		    ret[e.target.name] = e.target.value.toUpperCase();
		    return XHR.get(xhro + encPpties(ret) );
		}

		app.remove = e => {
		    const clave = e.target.parentElement.dataset.clave;
		    if (window.confirm('Estas seguro de eliminar este articulo?'))
			XHR.get(xhro + encPpties({clave: clave, tbname: 'datos', desc: 'VVVVV'}))
			.then( () => DATA.inplace({clave: clave}) );
		};

		BROWSE.rows = function( a, row ) {
		    row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		    let clave = row.insertCell();
		    clave.addEventListener('click', app.selectme);
		    if (a.selected) { clave.classList.add('gold'); }
		    clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		    let desc = row.insertCell();
		    desc.classList.add('desc');
		    if (a.faltante == 2) { desc.classList.add('faltante'); } // app.css 4 PEDIDO
		    desc.appendChild( document.createTextNode( a.desc ) );
		    let costol = row.insertCell();
		    costol.classList.add('total');
		    costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
		    let obs = document.createElement('input');
		    obs.name = 'obs'; obs.value = a.obs || ''; obs.size = 12; obs.addEventListener('change', update);
		    row.insertCell().appendChild( obs );
		    let prov = document.createElement('input');
		    prov.name = 'proveedor'; prov.value = a.proveedor || ''; prov.size = 12; prov.addEventListener('change', update);
		    row.insertCell().appendChild( prov );
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.name = 'faltante'; ie.checked = (a.faltante==2); ie.value = (a.faltante == 1 ? 2 : 1); ie.addEventListener('change', update);
		    row.insertCell().appendChild( ie );
		};

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
		    app.onLoaded();
		}

    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();

	};

