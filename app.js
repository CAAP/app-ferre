
        "use strict";

	const DATA = { VERSION: 2, DB: 'datos', STORE: 'datos-clave', INDEX: 'desc', KEY: 'clave', FILE: 'ferre.json' };
	const BAG = { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid', INDEX: 'fecha', KEY: 'uid', FILE: 'tickets.json' };
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
	};

	function loadDB(k) {
	    var req = indexedDB.open(k.DB, k.VERSION);
	    req.onerror = function(e) { note.innerHTML += '<li>Error loading database: ' + k.DB + ' | ' + e.target.errorCode + '. </li>'; };
	    req.onsuccess = function(e) { note.innerHTML += '<li>Database ' + k.DB + ' initialized.</li>'; data[k.DB] = this.result; };
	    req.onupgradeneeded = function(e) {
	        note.innerHTML += '<li>Upgrade ongoing.</li>';
                var objStore = e.currentTarget.result.createObjectStore(k.STORE, { keyPath: k.KEY });
                objStore.createIndex(k.INDEX, k.INDEX, { unique: false } );
                objStore.transaction.oncomplete = function(e) {
                    note.innerHTML += '<li> ObjectStore ' + k.STORE + ' created successfully. </li>';
//		    populateDB();
                };
	    };
	}

 	function randString(len) {
	    var ret = "";
	    for(var i=0; i<len; i++)
		ret += ALPHA.charAt(Math.floor(Math.random() * ALPHA.length + 0.5));
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

	function clearDB() {
	    var k = BAG;
	    var objStore = write2DB( k );
	    var req = objStore.clear();
	    req.onsuccess = function() { note.innerHTML = '<li> Data cleared. </li>' };
	}

	function reloadDB() {
	    var k = DATA;
	    clearDB( k );
	    populateDB();
	}

	function countDB() {
	    var k = BAG;
	    var objStore = readDB( k );
	    var req = objStore.count();
	    req.onsuccess = function() { note.innerHTML = '<li> Count: ' + req.result + '</li>'; }
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

	function asnum(s) {
	    var n = Number(s);
	    return Number.isNaN(n) ? s : n;
	}

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
            var index = readDB( DATA ).index("desc");
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
 
        function inputChange(e) {
            search(e.target.value);
            e.target.value = "";
        }
        
        function keyPressed(e) {
            if (e.key == 'Escape')
                e.target.value = "";
        }

	function changedEvent(e) { console.log(e.target.name + ': ' + e.target.value); }

	function precios(q) {
	    var ret = '<select name="precio"><option value="precio1" selected>'+q.precio1+' / '+q.u1+'</option>';
	    ret += q.precio2>0 ? '<option value="precio2">'+q.precio2+' / '+q.u2+'</option>': '';
	    ret += q.precio3>0 ? '<option value="precio3">'+q.precio3+' / '+q.u3+'</option>': '';
	    ret += '</select>';
	    return ret;
	}

	function getTicket() {
	    if (session.get('ticket'))
		return session.ticket;
	    else {
	        var uid = randString(STRLEN);
	        var newTicket = { uid: uid, fecha: TODAY.toLocaleDateString('es'), version: 1.0, items: {} };
	        var objStore = write2DB( BAG );
	        objStore.add( newTicket );
	        session.ticket = uid;
	        return uid;
	    }
	}

	function add2bag(e) {
	    resultados.style.visibility='hidden';
	    ans.innerHTML = '';
	    if (hideBag) {
		document.getElementById('ticket').style.visibility='visible';
		hideBag = false;
	    }
	    
	    var clave = asnum( e.target.parentElement.dataset.clave );
	    console.log('Click on me: '+clave);

	    var ticket = getTicket();
//	    newTicket.items[clave] = { qty: 1, precio: 'precio1', rea: 0, version: 1, total: 0 };
 
	    var req = readDB( DATA ).get( clave );
	    req.onsuccess = function(ev) {
		var q = ev.target.result;
		bag.innerHTML += '<tr data-clave="'+q.clave+'"><td><input name="qty" type="text" size=3 value=1></td><td class="basura">'+q.desc+'</td><td class="pesos">'+precios(q)+'</td><td class="pesos"><input name="rea" type="text" size=2 value=0>%</td><td class="pesos">'+q.precio1+'</td></tr>';
	    };
	}

	function item2bin(e) {
	    console.log('Clave: ' + e.target.parentElement.dataset.clave );
	    var child = bag.removeChild( e.target.parentElement );
	    if (!bag.hasChildNodes()) {
		document.getElementById('ticket').style.visibility='hidden';
		hideBag = true;
	    }
	}

