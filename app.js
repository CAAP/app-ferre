
        "use strict";

	var ferre = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', INDEX: 'desc', KEY: 'clave', FILE: 'ferre.json' },
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid', INDEX: 'fecha', KEY: 'uid' },
	    TICKET: { VERSION: 1, DB: 'ticket', STORE: 'ticket-clave', KEY: 'clave' },
	    STRLEN: 5,
	    ALPHA: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz",
	    DATEFORMAT: { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' },
	};

	ferre.addFuns = function addFuns() {
	    var IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    var indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
	    var note = document.getElementById('notifications');
	    var res = document.getElementById('resultados');
            var ans = document.getElementById('tabla-resultados');
	    var bag = document.getElementById('ticket-compra');
	    var ttotal = document.getElementById('ticket-total');
	    var myticket = document.getElementById('ticket');
	    var HIDEBAG = true;
	    var N = 50;
	    var TODAY = new Date();
	    var TICKET = ferre.TICKET;
	    var DATA = ferre.DATA;
	    var DBs = [ DATA, TICKET];

	    var asnum = function asnum(s) { var n = Number(s); return Number.isNaN(n) ? s : n; };

	    var tocents = function tocents(x) { return (x / 100).toFixed(2); };

	    var totalCents = function(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    var isSelected = function isSelected(pred) { return pred ? 'selected>' : '>'; };

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
		var req = write2DB( k ).objStore.clear();
		req.onsuccess = function() { console.log( 'Data cleared from DB; ' + k.DB ); };
	    }

	    var bagTotal = function bagTotal() {
		var total = 0;
		ttotal.innerHTML = '';
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if (cursor) {
			total += cursor.value.totalCents; //precioTotal( cursor.value );
			cursor.continue();
		    } else { ttotal.innerHTML = tocents( total ); }
		};
	    };

//anon FN defined
	    var populateDB = function populateDB( k ) {
		var xhttp = new XMLHttpRequest();
		xhttp.open('GET', 'ferre.json');
        	xhttp.onreadystatechange = function() {
		    if (xhttp.readyState == 4) {
			var mydata = eval( '(' +  xhttp.responseText + ')' );
			var datos = mydata.vs
			var ks = mydata.ks
			var asobj = function asobj(a) {
			    var ret = {};
			    for (var i in ks) { ret[ks[i]] = a[i]; }
			    return ret;
			};
			var objStore = write2DB( k );
			for (var i in datos) { objStore.add( asobj(datos[i]) ); }
			console.log( 'Data loaded to DB: ' + k.DB );
		    }
                };
		xhttp.send(null);
	    };

	    var loadDB = function loadDB(k) {
		var req = indexedDB.open(k.DB, k.VERSION);
		req.onerror = function(e) {  console.log('Error loading database: ' + k.DB + ' | ' + e.target.errorCode); };
	        req.onsuccess = function(e) { note.innerHTML += '<li>Database ' + k.DB + ' initialized.<li>'; k.CONN = e.target.result; if (k.DB == 'ticket') { loadTICKET(); } };
		req.onupgradeneeded = function(e) {
		    console.log('Upgrade ongoing.');
		    var objStore = e.target.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		    if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
		    objStore.transaction.oncomplete = function(ev) {
			console.log('ObjectStore ' + k.STORE + ' created successfully.');
			if (k.FILE) { populateDB( k.FILE ); }
		    };
		};
	    };

	    var precios = function precios(q) {
		var ret = '<select name="precio"><option value="precio1"'+isSelected(q.precio=='precio1')+q.precio1+' / '+q.u1+'</option>';
		ret += q.precio2>0 ? '<option value="precio2"'+isSelected(q.precio=='precio2')+q.precio2+' / '+q.u2+'</option>': '';
		ret += q.precio3>0 ? '<option value="precio3"'+isSelected(q.precio=='precio3')+q.precio3+' / '+q.u3+'</option>': '';
		ret += '</select>';
		return ret;
	    };

	    var displayItem = function displayItem(q) {
		var ret = '<tr data-clave="'+q.clave+'">';
		ret += '<td><input name="qty" type="text" size=2 value='+q.qty+'></td>';
		ret += '<td class="basura">'+q.desc+'</td>';
		ret += '<td class="pesos">'+precios(q)+'</td>';
		ret += '<td class="pesos"><input name="rea" type="text" size=2 value='+q.rea+'>%</td>';
		ret += '<td class="pesos"><label class="total">'+tocents( q.totalCents )+'<label></td></tr>';
		bag.innerHTML += ret;
	    };

// REPEATED CODE | LOOK ABOVE
	    var loadTICKET = function loadTICKET() {
		var objStore = readDB(TICKET);
		var req = objStore.count();
		req.onsuccess = function(e) {
		    if (req.result > 0) {
			myticket.style.visibility='visible';
			HIDEBAG = false;
			var total = 0;
			objStore.openCursor().onsuccess = function(ev) {
			    var cursor = ev.target.result;
			    if (cursor) {
				total += cursor.value.totalCents; //precioTotal( cursor.value );
			        displayItem( cursor.value );
		    	        cursor.continue();
			    } else { ttotal.innerHTML = tocents( total ); }
			};
		    }
		};
	    };

	    var newItem = function newItem(a, j) {
		var row = ans.insertRow(j);
		row.dataset.clave = a.clave;
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		row.insertCell().appendChild( document.createTextNode( a.clave ) );
		row.insertCell().appendChild( document.createTextNode( a.desc ) );
		for (var k=1; k<4; k++) {
		    if (a['precio'+k] > 0) {
			var node = row.insertCell();
			node.appendChild( document.createTextNode(a['precio'+k]+' / '+a['u'+k]) );
			node.class = 'pesos';
		    }
		}
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

	    var searching = function searching(j) {
		var k = 0;
		return function(e) {
		    var cursor = e.target.result;
		    if (cursor && k < N) {
			newItem(cursor.value, j);
			k++;
			cursor.continue();
		    } else { res.scrollTop = N*27; }
		};
	    };

	    var searchByDesc = function searchByDesc(s) {
		console.log('Searching by description.');
		var index = readDB( DATA ).index( DATA.INDEX );
		var rangeUp = IDBKeyRange.lowerBound(s);
		var rangeDown = IDBKeyRange.upperBound(s,true);
		index.openCursor( rangeUp ).onsuccess = searching(-1);
		index.openCursor( rangeDown, 'prev' ).onsuccess = searching(0);
	    };

	    var searchByClave = function searchByClave(s) {
		console.log('Searching by clave.');
		var req = readDB( DATA ).get( asnum(s) );
		req.onerror =  function(e) { console.log('Error searching by clave.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { var ss = e.target.result.desc; searchByDesc(ss) } //newItem(e.target.result);
		    else { searchByDesc(s); }
		};
	    };

	    var startSearch = function startSearch(e) {
		document.getElementById('resultados').style.visibility='visible';
		ans.innerHTML = '';
		searchByClave(e.target.value);
		e.target.value = ""; // clean input field
	    };

	    var toggleBag = function toggleBag() {
		if (!bag.hasChildNodes()) {
		    myticket.style.visibility='hidden';
		    HIDEBAG = true;
		} else { bagTotal(); }
	    };

 	    ferre.indexedDB = indexedDB;

 	    ferre.startSearch = startSearch;

	    ferre.loadDBs = function loadDBs() { DBs.forEach( loadDB ); };

	    ferre.header = function ferreTodate() {
		var DATEFORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		var today = TODAY.toLocaleDateString('es-MX', this.DATEFORMAT);
		note.innerHTML = '<li>' + today + '</li>';
	    }

	    ferre.footer = function footer() {
		document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';
	    };

	    ferre.keyPressed = function keyPressed(e) {
		switch (e.key) {
		    case 'Escape':
		    case 'Esc':
			e.target.value = "";
			break;
		    case 'ArrowUp':
		    case 'ArrowDown':
		    case 'Up':
		    case 'Down':
			startSearch(e);
			break;
		    default: break;
		}
	    };

	    ferre.add2bag = function add2bag(e) {
		var clave = asnum( e.target.parentElement.dataset.clave );
		resultados.style.visibility='hidden';
		ans.innerHTML = '';
		if (HIDEBAG) {
		    myticket.style.visibility='visible';
		    HIDEBAG = false;
		}
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
		    q[k] = v;
		    var reqUpdate = objStore.put( q );
		    reqUpdate.onerror = function(eve) { console.log( 'Error updating item in ticket.' ); };
		    reqUpdate.onsuccess = function(eve) { q.totalCents = totalCents(q); lbl.innerHTML = tocents( q.totalCents ); bagTotal(); };
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
		    bag.innerHTML = '';
		    toggleBag();
		};
	    };

/*
	    ferre.reloadDB = function reloadDB() {
		clearDB( DATA );
		populateDB( DATA );
	    };
*/
	};

	window.onload = function() {
	    ferre.addFuns();
	    ferre.header();
	    ferre.footer();
	    if (ferre.indexedDB) { ferre.loadDBs(); }
	    else { alert('IDBIndexed not available.'); }
	};

 	function randString(len) {
	    var ret = "";
	    for(var i=0; i<len; i++)
		ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length ));
	    return ret;
	}


	function countDB() {
	    var k = TICKET;
	    var objStore = readDB( k );
	    var req = objStore.count();
	    req.onsuccess = function() { note.innerHTML += '<li> Count: ' + req.result + '</li>'; }
	}

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
 

