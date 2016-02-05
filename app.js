
        "use strict";

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

	    var sstr = '';

	    var asnum = function asnum(s) { var n = Number(s); return Number.isNaN(n) ? s : n; };

	    var tocents = function tocents(x) { return (x / 100).toFixed(2); };

	    var topesos = function topesos(x) { return (x / 100).toLocaleString('es-MX', {style:'currency', currency:'MXN'}); };

	    var totalCents = function(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    var now = function(fmt) { return new Date().toLocaleDateString('es-MX', fmt) };

	    var transaction = function transaction(t) {
		return function initTransaction( k ) {
		    var trn = k.CONN.transaction(k.STORE, t);
		    trn.oncomplete = function(e) { console.log(t +' transaction successfully done.'); };
		    trn.onerror = function(e) { console.log( t + ' transaction error:' + e.target.errorCode); };
		    return trn.objectStore(k.STORE);
		};
	    };

	    var write2DB = transaction("readwrite");

	    var readDB = transaction("readonly");

	    var clearDB = function clearDB( k ) {
		var req = write2DB( k ).clear();
		req.onsuccess = function() { console.log( 'Data cleared from DB; ' + k.DB ); };
	    }

	    var clearTable = function(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    var toggleTicket = function toggleTicket() {
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    myticket.style.visibility = 'hidden';
	    }

	    var bagTotal = function bagTotal() {
		var total = 0;
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if (cursor) {
			total += cursor.value.totalCents;
			cursor.continue();
		    } else { ttotal.textContent = tocents( total ); }
		};
	    };

	    var asobj = function asobj(a, ks) {
		var ret = {};
		for (var i in ks) { ret[ks[i]] = a[i]; }
		return ret;
	    };

	    var populateDB = function populateDB( k ) {
		var xhttp = new XMLHttpRequest();
		xhttp.open('GET', k.FILE);
        	xhttp.onreadystatechange = function() {
		    if (xhttp.readyState == 4) {
			var mydata = eval( '(' +  xhttp.responseText + ')' );
			var datos = mydata[1];
			var ks = mydata[0];
			var objStore = write2DB( k );
			for (var i in datos) { objStore.add( asobj(datos[i], ks) ); }
			console.log( 'Data loaded to DB: ' + k.DB );
		    }
                };
		xhttp.send(null);
	    };

	    var loadDB = function loadDB(k) {
		var req = indexedDB.open(k.DB, k.VERSION);
		req.onerror = function(e) {  console.log('Error loading database: ' + k.DB + ' | ' + e.target.errorCode); };
	        req.onsuccess = function(e) { k.CONN = e.target.result; if (k.load) { k.load(); }};//if (k.DB == 'ticket') { loadTICKET(); } };
		req.onupgradeneeded = function(e) {
		    console.log('Upgrade ongoing.');
		    var objStore = e.target.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		    if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
		    objStore.transaction.oncomplete = function(ev) {
			console.log('ObjectStore ' + k.STORE + ' created successfully.');
			if (k.FILE) { populateDB( k ); }
		    };
		};
	    };

	    var incdec = function incdec(e) {
		switch (e.key || e.which) {
		    case '+':
		    case 'Add':
		    case 187:
			e.target.value++;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    case '-':
		    case 'Subtract':
		    case 189:
			if (e.target.value == 1) { e.preventDefault(); break; }
			e.target.value--;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    default: break;
		}
	    }

	   var inputE = function inputE( a ) {
		var ret = document.createElement('input');
		ret.addEventListener('keydown', incdec);
		a.map( function(o) { ret[o.k] = o.v;});
		return ret;
	   };

	    var precios = function precios(q) {
		if ((q.precio2 == 0) && (q.precio3 == 0)) { return document.createTextNode( q.precio1.toFixed(2) ); }
		var ret = document.createElement('select');
		ret.name = 'precio';
		for(var i=1;i<4;i++) {
		    var k = 'precio'+i;
		    if (q[k] > 0) {
			var opt = document.createElement('option');
			opt.value = k; opt.selected = (q.precio == k);
			opt.appendChild( document.createTextNode( q[k] + ' / ' + q['u'+i]) );
			ret.appendChild(opt);
		    }
		}
		return ret;
	    }

	    var displayItem = function displayItem(q) {
		var row = bag.insertRow();
		row.dataset.clave = q.clave;
		var qty = row.insertCell().appendChild( inputE( [{k:'type', v:'text'}, {k:'size', v:2}, {k:'name', v:'qty'}, {k:'value', v:q.qty}] ) );
		var desc = row.insertCell();
		desc.classList.add('basura'); desc.appendChild( document.createTextNode( q.desc ) );
		var pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		var rea = inputE( [{k:'type', v:'text'}, {k:'size', v:2}, {k:'name', v:'rea'}, {k:'value', v:q.rea}] );
		var td = row.insertCell(); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		var total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
	    };

	    PEOPLE.load = function loadPEOPLE() {
		var ol = document.createElement('ol');
		persona.appendChild(ol);
		var req = readDB( PEOPLE ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if(cursor) {
			ol.appendChild( document.createElement('li') ).textContent = cursor.value.nombre;
			cursor.continue();
		    } else {
			var ie = inputE( [{k: 'type', v:'text'}, {k:'size', v:1}] );
			ie.addEventListener('keydown', printing);
			persona.appendChild( ie );
		    }
		};
	    };

	    TICKET.load = function loadTICKET() {
		var objStore = readDB( TICKET );
		var req = objStore.count();
		req.onsuccess = function(e) {
		    if (req.result > 0) {
			toggleTicket();
			var total = 0;
			objStore.openCursor().onsuccess = function(ev) {
			    var cursor = ev.target.result;
			    if (cursor) {
				total += cursor.value.totalCents;
			        displayItem( cursor.value );
		    	        cursor.continue();
			    } else { ttotal.textContent = tocents( total ); }
			};
		    }
		};
	    };

// PRINTING //

	    var NUMS = {};
	    NUMS.C = {0: '', 1: 'CIENTO ', 2: 'DOSCIENTOS ', 3: 'TRESCIENTOS ', 4: 'CUATROCIENTOS ', 5: 'QUINIENTOS ', 6: 'SEISCIENTOS ', 7: 'SETECIENTOS ', 8: 'OCHOCIENTOS ', 9: 'NOVECIENTOS '};
	    NUMS.D = {0: '', 11: 'ONCE ', 12: 'DOCE ', 13: 'TRECE ', 14: 'CATORCE ', 15: 'QUINCE ', 16: 'DIECISEIS ', 17: 'DIECISIETE ', 18: 'DIECIOCHO ', 19: 'DIECINUEVE ', 2: 'VEINTI ', 3: 'TREINTA Y ', 4: 'CUARENTA Y ', 5: 'CINCUENTA Y ', 6: 'SESENTA Y ', 7: 'SETENTA Y ', 8: 'OCHENTA Y ', 9: 'NOVENTA Y '}
	    NUMS.I = {0: '', 1: 'UNO ', 2: 'DOS ', 3: 'TRES ', 4: 'CUATRO ', 5: 'CINCO ', 6: 'SEIS ', 7: 'SIETE ', 8: 'OCHO ', 9: 'NUEVE '};
	    NUMS.M = {3: 'MIL ', 6: 'MILLON '};

	    ferre.enpesos = function enpesos(x) {
		var y = Math.floor( Math.log10(x) )
		var z = x.toFixed(2);
		var ret = '';
		for (var i = 0; i<=y; i++) {
		    var j = z[i];
		    var k = y-i;
		    switch(k) {
		    case 5: case 2: ret += NUMS.C[j]; break;
		    case 4: case 1: ret += (j=='1' ? NUMS.D[j+z[++i]] : NUMS.D[j]); break;
		    case 3: case 6: ret += ((j=='1' ? 'UN ' : NUMS.I[j]) + NUMS.M[k]); break;
		    case 0: ret += NUMS.I[j];
		    }
		}
		ret += 'PESO(S) ' + z.substr(y+2) + '/100 M.N.'
		return ret;
	    };

	    var printTICKET = function printTICKET(nombre, numero) {
		var a = ['qty', 'rea'];
		var ret = '<html><link href="ticket.css" media="print" rel="stylesheet" />';
		ret += '<body><table><thead>';
		ret += '<tr><th colspan=4>FERRETERIA AGUILAR</th></tr>';
		ret += '<tr><th colspan=4>FERRETERIA Y REFACCIONES EN GENERAL</th></tr>';
		ret += '<tr><th colspan=4>Benito Juarez No 1C  Ocotlan, Oaxaca</th></tr>';
		ret += '<tr><th colspan=4>'+(new Date().toLocaleString())+'&emsp; Tel. 57-10076</th></tr>';
		ret += '<tr class="doble"><th>CNT</th><th>DSC</th><th>PRECIO</th><th>TOTAL</th></tr></thead><tbody>';

		var total = 0;
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if (cursor) {
			var q = cursor.value;
			total += q.totalCents;
			ret += '<tr><td colspan=4>'+q.desc+'&emsp;'+q['u'+q.precio[6]]+'</td></tr><tr>';
			a.map( function(k) { ret += '<td align="center">'+ q[k] +'</td>'; } );
			ret += '<td class="pesos">'+q[q.precio].toFixed(2)+'</td><td class="pesos">'+tocents(q.totalCents)+'</td></tr>';
			cursor.continue();
		    } else {
			ret += '<tfoot><tr class="total"><th colspan=4>Total de su compra: '+topesos(total)+'</th></tr>'
			ret += '<tr><th colspan=4>'+enpesos(total/100)+'</th></tr>'
			ret += '<tr><th colspan=2>'+nombre+'</th><th colspan=2 align="right">#'+numero+'</th></tr>';
			ret += '<tr><th colspan=4>GRACIAS POR SU COMPRA</th></tr></tfoot></tbody></table></body></html>'
			var iframe = document.createElement('iframe');
			iframe.width = 400;
			myticket.appendChild(iframe);
			var doc = iframe.contentWindow.document;
			doc.open();
			doc.write(ret);
			doc.close()
			iframe.contentWindow.onfocus = function (e) {  myticket.removeChild(myticket.lastChild); };
			iframe.contentWindow.print();
			iframe.contentWindow.focus();
		    }
		};
	    };

	    var STRLEN = 5;
	    var ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz";

	    var randString = function randString() {
		var ret = "";
		for (var i=0; i<STRLEN; i++) { ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length )); }
		return ret;
	    };

	    var printing = function printing(e) {
		var k = e.key || (e.which-48);
		persona.close(k);
		e.target.textContent = '';
		readDB( PEOPLE ).get( k ).onsuccess = function(e) { var q = e.target.result; if (q) { printTICKET(q.nombre, randString()); } };
	    };

	    ferre.printDialog = function printDialog(args) { persona.showModal(); } // args ADD ticket or budget

// PRINTING //


	    var newItem = function newItem(a, j) {
		var row = ans.insertRow(j);
		if (a.desc.includes(sstr)) { row.classList.add('encontrado'); };
		row.dataset.clave = a.clave;
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		row.insertCell().appendChild( document.createTextNode( a.clave ) );
		row.insertCell().appendChild( document.createTextNode( a.desc ) );
		row.insertCell().appendChild( document.createTextNode( a.precio1.toFixed(2) ) );
		row.insertCell().appendChild( document.createTextNode( a.u1 ) );
	    };

	    var item2ticket = function item2ticket(q) {
		var objStore = write2DB( TICKET )
		var req = objStore.get( q.clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { console.log('Item is already in the bag.'); }
		    else {
			q.qty =  1; q.precio = 'precio1'; q.rea = 0; q.version = 1; q.totalCents = totalCents(q);
			var reqUpdate = objStore.put( q );
			reqUpdate.onerror = function(e) { console.log('Error adding item to ticket.'); };
			reqUpdate.onsuccess = function(e) { displayItem(q); bagTotal(); };
		    }
		};
	    };

	    var browsing = function browsing(j, M) {
		var k = 0;
		return function(e) {
		    var cursor = e.target.result;
		    if (cursor && k < M) {
			newItem(cursor.value, j);
			k++;
			cursor.continue();
		    }
		};
	    };

	    var indexCursor = function searchIndex(index, t, s, M) {
		var NN = M || N;
		var range = (t.substr(0,4) == 'next') ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N);
		var j = (t.substr(0,4) == 'next') ? -1 : 0;
		index.openCursor( range, t ).onsuccess = browsing(j, NN);
	    }

	    var searchByDesc = function searchByDesc(s) {
		console.log('Searching by description:' + s);
		sstr = s;
		var index = readDB( DATA ).index( DATA.INDEX );
		indexCursor(index, 'next', s);
	    };

	    var searchByClave = function searchByClave(s) {
		console.log('Searching by clave:' + s);
		var req = readDB( DATA ).get( asnum(s) );
		req.onerror =  function(e) { console.log('Error searching by clave.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { var ss = e.target.result.desc; searchByDesc(ss) }
		    else { searchByDesc(s); }
		};
	    };

	    var startSearch = function startSearch(e) {
		document.getElementById('resultados').style.visibility='visible';
		clearTable( ans );
		searchByClave(e.target.value.toUpperCase());
		e.target.value = ""; // clean input field
	    };

	    var toggleBag = function toggleBag() {
		if (!bag.hasChildNodes())
		   toggleTicket();
		else
		    bagTotal();
	    };

 	    ferre.indexedDB = indexedDB;

 	    ferre.startSearch = startSearch;

	    ferre.loadDBs = function loadDBs() { DBs.forEach( loadDB ); };

	    ferre.header = function ferreTodate() {
	        var note = document.getElementById('notifications');
		var FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    }

	    ferre.footer = function footer() {
		document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';
	    };

	    ferre.keyPressed = function keyPressed(e) {
		switch (e.key || e.which) {
		    case 'Escape':
		    case 'Esc':
		    case 27:
			e.target.value = "";
			break;
		    case 'ArrowUp':
		    case 'ArrowDown':
		    case 'Up':
		    case 'Down':
		    case 38:
		    case 40:
			startSearch(e);
			break;
		    default: break;
		}
	    };

	    ferre.retrieve = function retrieve(t) {
		var s = (t == 'prev') ? ans.firstChild.querySelector('.desc').textContent : ans.lastChild.querySelector('.desc').textContent;
		if (t == 'prev') { ans.removeChild( ans.lastChild ); } else { ans.removeChild( ans.firstChild ); }
		var index = readDB( DATA ).index( DATA.INDEX );
		indexCursor(index, t, s, 1);
	    };

	    ferre.scroll = function scroll(e) {
		if (e.deltaY > 0)
		    ferre.retrieve('next');
		else
		    ferre.retrieve('prev');
	    };

	    ferre.add2bag = function add2bag(e) {
		var clave = asnum( e.target.parentElement.dataset.clave );
		(myticket.classList.contains('visible') || toggleTicket());
		var req = readDB( DATA ).get( clave );
		req.onsuccess = function(e) {
		    var q = e.target.result;
		    item2ticket(q);
		};
	    };

	    ferre.updateItem = function updateItem(e) {
		var tr = e.target.parentElement.parentElement;
		var lbl = tr.querySelector('.total');
		var clave = asnum( tr.dataset.clave );
		var k = e.target.name;
		var v = e.target.value;

		console.log( clave + ' - ' + k + ': ' + v);

		var objStore = write2DB( TICKET )
		var req = objStore.get( clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(ev) {
		    var q = this.result;
		    q[k] = asnum( v ); // FORCE cast to NUMBER
		    q.totalCents = totalCents(q); // UPDATE partial TOTAL
		    var reqUpdate = objStore.put( q );
		    reqUpdate.onerror = function(eve) { console.log( 'Error updating item in ticket.' ); };
		    reqUpdate.onsuccess = function(eve) { lbl.textContent = tocents( q.totalCents ); bagTotal(); };
		};
	    };

	    ferre.item2bin = function item2bin(e) {
		var clave = asnum( e.target.parentElement.dataset.clave );
		var tr = e.target.parentElement;
		var req = write2DB( TICKET ).delete( clave );
		req.onsuccess = function(ev) {
		    bag.removeChild( tr );
		    toggleBag();
		};
	    };

	    ferre.emptyBag = function emptyBag(e) {
		var req = write2DB( TICKET ).clear()
		req.onsuccess = function(ev) {
		    clearTable( bag );
		    toggleBag();
		};
	    };

	    ferre.reloadDB = function reloadDB() {
		clearDB( DATA );
		populateDB( DATA );
	    };
	};

	window.onload = function() {
	    ferre.addFuns();
	    ferre.header();
	    ferre.footer();
	    if (ferre.indexedDB) { ferre.loadDBs(); }
	    else { alert('IDBIndexed not available.'); }
	};

	function getUID() {
	    if (!session.UID) {
	        var uid = randString(STRLEN);
	        var newTicket = { uid: uid, fecha: TODAY.toLocaleDateString('es'), version: 1.0, items: new Map() };
	        var objStore = write2DB( BAG );
	        objStore.add( newTicket );
	        session.UID = uid;
	    }
	    return session.UID;
	}
 
