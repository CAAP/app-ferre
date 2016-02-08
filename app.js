
        "use strict";

	window.onload = function() {
	    ferre.addFuns();
	    ferre.header();
	    ferre.footer();
	    if (ferre.indexedDB) { ferre.loadDBs(); }
	    else { alert('IDBIndexed not available.'); }
	};

	var ferre = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' },
	    TICKET: { VERSION: 1, DB: 'ticket', STORE: 'ticket-clave', KEY: 'clave' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	};

	ferre.addFuns = function addFuns() {
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
	    const res = document.getElementById('resultados');
            const ans = document.getElementById('tabla-resultados');
	    const bag = document.getElementById('ticket-compra');
	    const ttotal = document.getElementById('ticket-total');
	    const myticket = document.getElementById('ticket');
	    const persona = document.getElementById('persona');
	    const N = 11;
	    const TICKET = ferre.TICKET;
	    const DATA = ferre.DATA;
	    const PEOPLE = ferre.PEOPLE;
	    const DBs = [ DATA, TICKET, PEOPLE ];

	    let sstr = '';

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function tocents(x) { return (x / 100).toFixed(2); };

	    function topesos(x) { return (x / 100).toLocaleString('es-MX', {style:'currency', currency:'MXN'}); };

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) };

 	    ferre.indexedDB = indexedDB;

	    ferre.loadDBs = function loadDBs() { DBs.forEach( loadDB ); };

	    ferre.header = function ferreTodate() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    }

	    ferre.footer = function footer() {
		document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';
	    };

	    ferre.reloadDB = function reloadDB() {
		clearDB( DATA );
		populateDB( DATA );
	    };

	    function transaction(t) {
		return function initTransaction( k ) {
		    let trn = k.CONN.transaction(k.STORE, t);
		    trn.oncomplete = function(e) { console.log(t +' transaction successfully done.'); };
		    trn.onerror = function(e) { console.log( t + ' transaction error:' + e.target.errorCode); };
		    return trn.objectStore(k.STORE);
		};
	    };

	    let write2DB = transaction("readwrite");

	    let readDB = transaction("readonly");

	    function clearDB( k ) {
		let req = write2DB( k ).clear();
		req.onsuccess = function() { console.log( 'Data cleared from DB; ' + k.DB ); };
	    };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    function asobj(a, ks) {
		let ret = {};
		for (let i in ks) { ret[ks[i]] = a[i]; }
		return ret;
	    };

	    function populateDB( k ) {
		let xhttp = new XMLHttpRequest();
		xhttp.open('GET', k.FILE);
        	xhttp.onreadystatechange = function() {
		    if (xhttp.readyState == 4) {
			let mydata = eval( '(' +  xhttp.responseText + ')' );
			let datos = mydata[1];
			let ks = mydata[0];
			let objStore = write2DB( k );
			datos.map( x => objStore.add(asobj(x, ks)) ); // for (let i in datos) { objStore.add( asobj(datos[i], ks) ); }
			console.log( 'Data loaded to DB: ' + k.DB );
		    }
                };
		xhttp.send(null);
	    };

	    function loadDB(k) {
		let req = indexedDB.open(k.DB, k.VERSION);
		req.onerror = function(e) {  console.log('Error loading database: ' + k.DB + ' | ' + e.target.errorCode); };
	        req.onsuccess = function(e) { k.CONN = e.target.result; if (k.load) { k.load(); }};
		req.onupgradeneeded = function(e) {
		    console.log('Upgrade ongoing.');
		    let objStore = e.target.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		    if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
		    objStore.transaction.oncomplete = function(ev) {
			console.log('ObjectStore ' + k.STORE + ' created successfully.');
			if (k.FILE) { populateDB( k ); }
		    };
		};
	    };

	    function incdec(e) {
		switch (e.key || e.which) {
		    case '+':
		    case 'Add':
		    case 187: case 107:
			e.target.value++;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    case '-':
		    case 'Subtract':
		    case 189: case 109:
			if (e.target.value == 1) { e.preventDefault(); break; }
			e.target.value--;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    default: break;
		}
	    }

	   function inputE( a ) {
		let ret = document.createElement('input');
		ret.addEventListener('keydown', incdec);
		a.map( o => ret[o[0]] = o[1] ); //  function(o) { ret[o[0]] = o[1];});
		return ret;
	   };

	    PEOPLE.load = function loadPEOPLE() {
		let ol = document.createElement('ol');
		persona.appendChild(ol);
		let req = readDB( PEOPLE ).openCursor().onsuccess = function(e) {
		    let cursor = e.target.result;
		    if(cursor) {
			ol.appendChild( document.createElement('li') ).textContent = cursor.value.nombre;
			cursor.continue();
		    } else {
			let ie = inputE( [['type', 'text'], ['size', 1]] );
			ie.addEventListener('keydown', printing);
			persona.appendChild( ie );
		    }
		};
	    };

// PRINTING //

	    let printing = (function() {
		let NUMS = {};
		NUMS.C = {0: '', 1: 'CIENTO ', 2: 'DOSCIENTOS ', 3: 'TRESCIENTOS ', 4: 'CUATROCIENTOS ', 5: 'QUINIENTOS ', 6: 'SEISCIENTOS ', 7: 'SETECIENTOS ', 8: 'OCHOCIENTOS ', 9: 'NOVECIENTOS '};
		NUMS.D = {0: '', 10: 'DIEZ ', 11: 'ONCE ', 12: 'DOCE ', 13: 'TRECE ', 14: 'CATORCE ', 15: 'QUINCE ', 16: 'DIECISEIS ', 17: 'DIECISIETE ', 18: 'DIECIOCHO ', 19: 'DIECINUEVE ', 3: 'TREINTA ', 4: 'CUARENTA ', 5: 'CINCUENTA ', 6: 'SESENTA ', 7: 'SETENTA ', 8: 'OCHENTA ', 9: 'NOVENTA '}
		NUMS.I = {0: '', 1: 'UNO ', 2: 'DOS ', 3: 'TRES ', 4: 'CUATRO ', 5: 'CINCO ', 6: 'SEIS ', 7: 'SIETE ', 8: 'OCHO ', 9: 'NUEVE '};
		NUMS.M = {3: 'MIL ', 6: 'MILLON '};

		let HEADER = ['<html><head><link rel="stylesheet" href="ticket.css" media="print"></head><body><table><thead>', '', '<tr><th colspan=4>FERRETERIA AGUILAR</th></tr><tr><th colspan=4>FERRETERIA Y REFACCIONES EN GENERAL</th></tr><tr><th colspan=4>Benito Juarez No 1C  Ocotlan, Oaxaca</th></tr><tr><th colspan=4>', '', '&emsp; Tel. 57-10076</th></tr><tr class="doble"><th>CNT</th><th>DSC</th><th>PRECIO</th><th>TOTAL</th></tr></thead><tbody>']
		const STRLEN = 5;
		const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz";
		let TKT = '';

		function decenas(d,u) {
		    let ret = '';
		    switch(d) {
			case '1': return NUMS.D[d+u];
			case '2': ret += (u=='0' ? 'VEINTE ': 'VEINTI'); break;
			default: ret += NUMS.D[d] + (u == '0' ? '' : 'Y ');
		    }
		    return ret + NUMS.I[u];
		};

		function enpesos(x) {
		    let y = Math.floor( Math.log10(x) );
		    let z = x.toFixed(2);
		    let ret = '';
		    for (let i = 0; i<=y; i++) {
			let j = z[i];
			let k = y-i;
			switch(k) {
			    case 5: case 2: ret += NUMS.C[j]; break;
			    case 4: case 1: ret += decenas(j, z[++i]); break;
			    case 3: case 6: ret += ((j=='1' ? 'UN ' : NUMS.I[j]) + NUMS.M[k]); break;
			    case 0: ret += NUMS.I[j];
			}
		    }
		    ret += 'PESO(S) ' + z.substr(y+2) + '/100 M.N.'
		    return ret;
		}

		function randString() {
		    let ret = "";
		    for (let i=0; i<STRLEN; i++) { ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length )); }
		    return ret;
		};

		function header() {
		    HEADER[3] = new Date().toLocaleString();
		    let ret = '';
		    HEADER.map( x => ret += x); //function(x) { ret += x; } );
		    return ret;
		};

		function printTicket(nombre, numero) {
		    TKT += '<tr><th colspan=2>'+nombre+'</th><th colspan=2 align="left">#'+numero+'</th></tr>';
		    TKT += '<tr><th colspan=4 align="center">GRACIAS POR SU COMPRA</th></tr></tfoot></tbody></table></body></html>'
		    let iframe = document.createElement('iframe');
		    iframe.style.visibility = "hidden";
		    iframe.width = 400;
		    iframe.onload = function() {
			let doc = this.contentWindow.document; doc.open(); doc.write(TKT); doc.close();
			this.contentWindow.__container__ = this;
			this.contentWindow.onfocus = function () { myticket.removeChild(myticket.lastChild); };
		    };
		    myticket.appendChild( iframe );
		    let printing = function printing() {
			iframe.contentWindow.print();
			iframe.contentWindow.focus();
		    };
		    window.setTimeout(printing, 500);
		};

		function setPrint() {
		    let a = ['qty', 'rea'];
		    TKT = header();
		    let total = 0;
		    readDB( TICKET ).openCursor().onsuccess = function(e) {
			let cursor = e.target.result;
			if (cursor) {
			    let q = cursor.value;
			    total += q.totalCents;
			    TKT += '<tr><td colspan=4>'+q.desc+'&emsp;'+q['u'+q.precio[6]]+'</td></tr><tr>';
			    a.map( function(k) { TKT += '<td align="center">'+ q[k] +'</td>'; } );
			    TKT += '<td class="pesos">'+q[q.precio].toFixed(2)+'</td><td class="pesos">'+tocents(q.totalCents)+'</td></tr>';
			    cursor.continue();
			}  else {
			    TKT += '<tfoot><tr><th colspan=4 class="total">Total de su compra: '+topesos(total)+'</th></tr>'
			    TKT += '<tr><th colspan=4>'+enpesos(total/100)+'</th></tr>'
			    persona.showModal();
			}
		    };
		};

		ferre.printDialog = function printDialog(args) { HEADER[1] = (args=='ticket' ? '' : '<tr><th colspan=4>PRESUPUESTO</th></tr>'); setPrint(); };

		return function printing(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    persona.close(k);
		    e.target.textContent = '';
		    readDB( PEOPLE ).get( k ).onsuccess = function(e) { let q = e.target.result; if (q) { printTicket(q.nombre, randString()); } };
		}

	    })();


// ==== BROWSING ==== //

	    (function() {

	    function newItem(a, j) {
		let row = ans.insertRow(j);
		if (a.desc.startsWith(sstr)) { row.classList.add('encontrado'); };
		row.dataset.clave = a.clave;
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		row.insertCell().appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for browsing
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		row.insertCell().appendChild( document.createTextNode( a.precio1.toFixed(2) ) );
		row.insertCell().appendChild( document.createTextNode( a.u1 ) );
	    };

	    function browsing(j, M) {
		let k = 0;
		return function(e) {
		    let cursor = e.target.result;
		    if (cursor && k < M) {
			newItem(cursor.value, j);
			k++;
			cursor.continue();
		    }
		};
	    };

	    function searchIndex(index, t, s, M) {
		let NN = M || N;
		let range = (t.substr(0,4) == 'next') ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N);
		let j = (t.substr(0,4) == 'next') ? -1 : 0;
		index.openCursor( range, t ).onsuccess = browsing(j, NN);
	    }

	    function searchByDesc(s) {
		console.log('Searching by description:' + s);
		sstr = s;
		let index = readDB( DATA ).index( DATA.INDEX );
		searchIndex(index, 'next', s);
	    };

	    function searchByClave(s) {
		console.log('Searching by clave:' + s);
		let req = readDB( DATA ).get( asnum(s) );
		req.onerror =  function(e) { console.log('Error searching by clave.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { let ss = e.target.result.desc; searchByDesc(ss) }
		    else { searchByDesc(s); }
		};
	    };

	    function startSearch(e) {
		document.getElementById('resultados').style.visibility='visible';
		clearTable( ans );
		searchByClave(e.target.value.toUpperCase());
		e.target.value = ""; // clean input field
	    };

	    function retrieve(t) {
		let s = (t == 'prev') ? ans.firstChild.querySelector('.desc').textContent : ans.lastChild.querySelector('.desc').textContent;
		if (t == 'prev') { ans.removeChild( ans.lastChild ); } else { ans.removeChild( ans.firstChild ); }
		let index = readDB( DATA ).index( DATA.INDEX );
		searchIndex(index, t, s, 1);
	    };

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

// ==== TICKET ==== //

	    (function() {

	    TICKET.load = function loadTICKET() {
		let objStore = readDB( TICKET );
		let req = objStore.count();
		req.onsuccess = function(e) {
		    if (req.result > 0) {
			toggleTicket();
			let total = 0;
			objStore.openCursor().onsuccess = function(ev) {
			    let cursor = ev.target.result;
			    if (cursor) {
				total += cursor.value.totalCents;
			        displayItem( cursor.value );
		    	        cursor.continue();
			    } else { ttotal.textContent = tocents( total ); }
			};
		    }
		};
	    };

	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    function toggleTicket() {
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    myticket.style.visibility = 'hidden';
	    };

	    function bagTotal() {
		let total = 0;
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    let cursor = e.target.result;
		    if (cursor) {
			total += cursor.value.totalCents;
			cursor.continue();
		    } else { ttotal.textContent = tocents( total ); }
		};
	    };

	    function precios(q) {
		if ((q.precio2 == 0) && (q.precio3 == 0)) { return document.createTextNode( q.precio1.toFixed(2) ); }
		let ret = document.createElement('select');
		ret.name = 'precio';
		for(let i=1;i<4;i++) {
		    let k = 'precio'+i;
		    if (q[k] > 0) {
			let opt = document.createElement('option');
			opt.value = k; opt.selected = (q.precio == k);
			opt.appendChild( document.createTextNode( q[k] + ' / ' + q['u'+i]) );
			ret.appendChild(opt);
		    }
		}
		return ret;
	    }

	    function displayItem(q) {
		let row = bag.insertRow();
		row.dataset.clave = q.clave;
		let qty = row.insertCell().appendChild( inputE( [['type', 'text'], ['size', 2], ['name', 'qty'], ['value', q.qty]] ) );
		let desc = row.insertCell();
		desc.classList.add('basura'); desc.appendChild( document.createTextNode( q.desc ) );
		let pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		let rea = inputE( [['type', 'text'], ['size', 2], ['name', 'rea'], ['value', q.rea]] );
		let td = row.insertCell(); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		let total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
	    };

	    function item2ticket(q) {
		let objStore = write2DB( TICKET )
		let req = objStore.get( q.clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { console.log('Item is already in the bag.'); }
		    else {
			q.qty =  1; q.precio = 'precio1'; q.rea = 0; q.version = 1; q.totalCents = uptoCents(q);
			let reqUpdate = objStore.put( q );
			reqUpdate.onerror = function(e) { console.log('Error adding item to ticket.'); };
			reqUpdate.onsuccess = function(e) { displayItem(q); bagTotal(); };
		    }
		};
	    };

	    ferre.add2bag = function add2bag(e) {
		let clave = asnum( e.target.parentElement.dataset.clave );
		(myticket.classList.contains('visible') || toggleTicket());
		let req = readDB( DATA ).get( clave );
		req.onsuccess = function(e) {
		    let q = e.target.result;
		    item2ticket(q);
		};
	    };

	    ferre.updateItem = function updateItem(e) {
		let tr = e.target.parentElement.parentElement;
		let lbl = tr.querySelector('.total');
		let clave = asnum( tr.dataset.clave );
		let k = e.target.name;
		let v = e.target.value;

		console.log( clave + ' - ' + k + ': ' + v);

		let objStore = write2DB( TICKET )
		let req = objStore.get( clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(ev) {
		    let q = this.result;
		    q[k] = asnum( v ); // FORCE cast to NUMBER
		    q.totalCents = uptoCents(q); // UPDATE partial TOTAL
		    let reqUpdate = objStore.put( q );
		    reqUpdate.onerror = function(eve) { console.log( 'Error updating item in ticket.' ); };
		    reqUpdate.onsuccess = function(eve) { lbl.textContent = tocents( q.totalCents ); bagTotal(); };
		};
	    };

	    ferre.item2bin = function item2bin(e) {
		let clave = asnum( e.target.parentElement.dataset.clave );
		let tr = e.target.parentElement;
		let req = write2DB( TICKET ).delete( clave );
		req.onsuccess = function(ev) {
		    bag.removeChild( tr );
		    if (!bag.hasChildNodes()) { toggleTicket(); } else { bagTotal(); }
		};
	    };

	    ferre.emptyBag = function emptyBag(e) {
		let req = write2DB( TICKET ).clear()
		req.onsuccess = function(ev) {
		    clearTable( bag );
		    toggleTicket();
		};
	    };

	    })();

	};


