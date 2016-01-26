
        "use strict";

	const DATA = { VERSION: 2, DB: 'datos', STORE: 'datos-clave', INDEX: 'desc', KEY: 'clave', FILE: 'ferre.json' };
	const BAG = { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid', INDEX: 'fecha', KEY: 'uid', FILE: 'tickets.json' };
	const TICKET = { VERSION: 1, DB: 'ticket', STORE: 'ticket-clave', KEY: 'clave' };
	const STRLEN = 5;
	const TODAY = new Date();
	const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz";
        
        var note, bag, ans ;
        var data = {};
	var hideBag = true;
        var IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	var session = sessionStorage;

	window.onload = function() {
	    var opts = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    document.getElementById('fecha').innerHTML = TODAY.toLocaleDateString('es-MX', opts) + ' | versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';

            note = document.getElementById('notifications');
            ans = document.getElementById('tabla-resultados');
	    bag = document.getElementById('ticket-compra');

	    var indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;

	    loadDB(DATA);
	    loadDB(BAG);
	    loadDB(TICKET);
	};

	function loadDB(k) {
	    var req = indexedDB.open(k.DB, k.VERSION);
	    req.onerror = function(e) { note.innerHTML += '<li>Error loading database: ' + k.DB + ' | ' + e.target.errorCode + '. </li>'; };
	    req.onsuccess = function(e) { note.innerHTML += '<li>Database ' + k.DB + ' initialized.</li>'; data[k.DB] = this.result; if (k.DB == 'ticket') { loadTICKET(); } };
	    req.onupgradeneeded = function(e) {
	        note.innerHTML += '<li>Upgrade ongoing.</li>';
                var objStore = e.currentTarget.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
                objStore.transaction.oncomplete = function(ev) {
                    note.innerHTML += '<li> ObjectStore ' + k.STORE + ' created successfully. </li>';
		    if (k.FILE) { populateDB( k.FILE ); }
                };
	    };
	}

	function loadTICKET() {
	    var objStore = readDB(TICKET);
	    var req = objStore.count();
	    req.onsuccess = function(e) {
		if (req.result > 0) {
		    document.getElementById('ticket').style.visibility='visible';
		    hideBag = false;
		    objStore.openCursor().onsuccess = function(ev) {
			var cursor = ev.target.result;
			if (cursor) {
			    bag.innerHTML += displayItem( cursor.value );
		    	    cursor.continue();
			}
		    }
		}
	    };
	}

 	function randString(len) {
	    var ret = "";
	    for(var i=0; i<len; i++)
		ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length ));
	    return ret;
	}

        function write2DB( k ) {
	    note.innerHTML = '';
            var transaction = data[k.DB].transaction(k.STORE, "readwrite");
            transaction.oncomplete = function(e) { note.innerHTML += '<li> RW transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> RW transaction error:' + e.target.errorCode + '. </li>' };
            
            return transaction.objectStore(k.STORE);
        }
        
        function readDB( k ) {
	    note.innerHTML = '';
            var transaction = data[k.DB].transaction(k.STORE);
            transaction.oncomplete = function(e) { note.innerHTML += '<li> Read transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> Read transaction error:' + e.target.errorCode + '. </li>' };
            
            return transaction.objectStore(k.STORE);
        }

	function clearDB( k ) {
	    var objStore = write2DB( k );
	    var req = objStore.clear();
	    req.onsuccess = function() { note.innerHTML += '<li> Data cleared. </li>' };
	}

	function reloadDB() {
	    var k = DATA;
	    clearDB( k );
	    populateDB();
	}

	function countDB() {
	    var k = TICKET;
	    var objStore = readDB( k );
	    var req = objStore.count();
	    req.onsuccess = function() { note.innerHTML += '<li> Count: ' + req.result + '</li>'; }
	}
 
        function populateDB() {
	    var k = DATA;
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
		    }
                    
                    var objStore = write2DB( k );
                    for (var i in datos) { objStore.add( asobj(datos[i]) ); }
                    
                    note.innerHTML = '<li> Data loaded to DB. </li>';
                }
            };
            xhttp.send(null);
        }

	function search(s) {
	    document.getElementById('resultados').style.visibility='visible';
	    ans.innerHTML = '';
	    if (s.length < 5)
		searchByClave(s);
	    else
		searchByDesc(s);
	}
       
	function newItem(a) {
            var item = '<tr data-clave="' + a.clave + '"><td>' + a.fecha + '</td><td>' + a.desc + '</td><td class="pesos">' + a.precio1 + " / " + a.u1 + "</td>";
	    item += a.precio2>0 ? '<td class="pesos">'+a.precio2+" / "+a.u2+"</td>": '<td></td>';
	    item += a.precio3>0 ? '<td class="pesos">'+a.precio3+" / "+a.u3+"</td>": '<td></td>';
	    item += '</tr>';
	    return item;
	}

	function asnum(s) { var n = Number(s); return Number.isNaN(n) ? s : n; }

	function precioTotal(q) { return (q[q.precio] * q.qty * (1-q.rea/100)).toFixed(2); }

        function searchByClave(s) {
	    console.log('Searching by clave.');
	    var req = readDB( DATA ).get( asnum(s) );
	    req.onerror =  function(e) { console.log('Error searching by clave.'); };
	    req.onsuccess = function(e) {
		if (e.target.result)
		    ans.innerHTML += newItem(e.target.result);
		else
		    searchByDesc(s);
	    };
	}

        function searchByDesc(s) {
	    console.log('Searching by description.');
            var index = readDB( DATA ).index( DATA.INDEX );
            var descRange = IDBKeyRange.lowerBound(s);
	    var k = 0;
            index.openCursor( descRange ).onsuccess = function(e) {
		ans.style.cursor = "wait";
                var cursor = e.target.result;
                if (cursor) {
                    ans.innerHTML += newItem(cursor.value);
		    k++;
		    if (k == 20) { ans.style.cursor = "default"; return; }
                    cursor.continue();
                }
            };
        }

	function isSelected(pred) { return pred ? 'selected>' : '>'; }

	function precios(q) {
	    var ret = '<select name="precio"><option value="precio1"'+isSelected(q.precio=='precio1')+q.precio1+' / '+q.u1+'</option>';
	    ret += q.precio2>0 ? '<option value="precio2"'+isSelected(q.precio=='precio2')+q.precio2+' / '+q.u2+'</option>': '';
	    ret += q.precio3>0 ? '<option value="precio3"'+isSelected(q.precio=='precio3')+q.precio3+' / '+q.u3+'</option>': '';
	    ret += '</select>';
	    return ret;
	}

	function displayItem(q) {
	    var ret = '<tr data-clave="'+q.clave+'">';
	    ret += '<td><input name="qty" type="text" size=3 value='+q.qty+'></td>';
	    ret += '<td class="basura">'+q.desc+'</td>';
	    ret += '<td class="pesos">'+precios(q)+'</td>';
	    ret += '<td class="pesos"><input name="rea" type="text" size=2 value='+q.rea+'>%</td>';
	    ret += '<td class="pesos"><label class="total">'+precioTotal(q)+'<label></td></tr>';
	    return ret;
	}

	function item2ticket(q) {
	    var objStore = write2DB( TICKET )
	    var req = objStore.get( q.clave );
	    req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
	    req.onsuccess = function(e) {
		if (e.target.result)
		    note.innerHTML += 'Item is already in the bag.';
		else {
		    q.qty =  1; q.precio = 'precio1'; q.rea = 0; q.version = 1;
		    var reqUpdate = objStore.put( q );
		    reqUpdate.onerror = function(e) { note.innerHTML += 'Error adding item to ticket.'; };
		    reqUpdate.onsuccess = function(e) { bag.innerHTML += displayItem(q); };
		}
	    };
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
 
        function inputChange(e) {
            search(e.target.value);
            e.target.value = "";
        }
        
        function keyPressed(e) {
            if (e.key == 'Escape')
                e.target.value = "";
        }

	function changeItem(e) {
	    var tr = e.target.parentElement.parentElement;
	    var lbl = tr.querySelector('.total');
	    var clave = asnum( tr.dataset.clave );
	    var k = e.target.name;
	    var v = e.target.value;

	    note.innerHTML = clave + ' - ' + k + ': ' + v;

	    var objStore = write2DB( TICKET )
	    var req = objStore.get( clave );
	    req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
	    req.onsuccess = function(ev) {
		var q = this.result;
		q[k] = v;
		var reqUpdate = objStore.put( q );
		reqUpdate.onerror = function(eve) { note.innerHTML += 'Error updating item in ticket.'; };
		reqUpdate.onsuccess = function(eve) { lbl.innerHTML = precioTotal(q); };
	    };
	}

	function add2bag(e) {
	    var clave = asnum( e.target.parentElement.dataset.clave );

	    resultados.style.visibility='hidden';
	    ans.innerHTML = '';
	    if (hideBag) {
		document.getElementById('ticket').style.visibility='visible';
		hideBag = false;
	    }
	    
	    var req = readDB( DATA ).get( clave );
	    req.onsuccess = function(e) {
		var q = e.target.result;
		item2ticket(q);
	    };
	}

	function item2bin(e) {
	    var clave = asnum( e.target.parentElement.dataset.clave );
	    var tr = e.target.parentElement;
	    var req = write2DB( TICKET ).delete( clave );
	    req.onsuccess = function(ev) {
		bag.removeChild( tr );
		if (!bag.hasChildNodes()) {
		    document.getElementById('ticket').style.visibility='hidden';
		    hideBag = true;
		}
	    };
	}

