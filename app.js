
        "use strict";

        const DB_DATA = 'datos';
       	const DB_BAG = 'tickets';
 	const DB_VERSION_DATA = 2;
	const DB_VERSION_BAG = 1;
        const DB_STORE_DATA = 'datos-clave';
	const DB_STORE_BAG = 'tickets-uid';
	const DB_INDEX_DATA = 'desc';
	const DB_INDEX_BAG = 'fecha';
	const STRLEN = 5;
	const TODAY = new Date();
	const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz";
        
        var note, bag, ans ;
        var data = {};
	var hideBag = true;
        var IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

	window.onload = function() {
	    var opts = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    document.getElementById('fecha').innerHTML = TODAY.toLocaleDateString('es-MX', opts) + ' | versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';

            note = document.getElementById('notifications');
            ans = document.getElementById('tabla-resultados');
	    bag = document.getElementById('ticket-compra');

	    var indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;

            var req1 = indexedDB.open(DB_DATA, DB_VERSION_DATA);
            req1.onerror = function(e) { note.innerHTML = '<li>Error loading database: '+ e.target.errorCode + '. </li>'; };
            req1.onsuccess = function(e) { note.innerHTML = '<li>Database initialized.</li>'; data[DB_DATA] = this.result; };
            req1.onupgradeneeded = function(e) {
                note.innerHTML += '<li>Upgrade ongoing.</li>';
                
                var objStore = e.currentTarget.result.createObjectStore(DB_STORE_DATA, { keyPath: "clave" });
                objStore.createIndex(DB_INDEX_DATA, DB_INDEX_DATA, { unique: false } );
                objStore.transaction.oncomplete = function(e) {
                    note.innerHTML += '<li> ObjectStore created. Ready to add data into it. </li>';
		    populateDB();
                };
	    };

	    var req2 = indexedDB.open(DB_BAG, DB_VERSION_BAG);
	    req2.onerror = function(e) { note.innerHTML += '<li>Error loading database: '+ e.target.errorCode + '. </li>'; };
	    req2.onsuccess = function(e) { note.innerHTML += '<li>Database initialized.</li>'; data[DB_BAG] = this.result; };
	    req2.onupgradeneeded = function(e) {
                note.innerHTML += '<li>Upgrade ongoing.</li>';
                
                var objStore = e.currentTarget.result.createObjectStore(DB_STORE_BAG, { keyPath: "uid" });
                objStore.createIndex(DB_INDEX_BAG, DB_INDEX_BAG, { unique: false } );
                objStore.transaction.oncomplete = function(e) {
                    note.innerHTML += '<li> ObjectStore created. Ready to add items into it. </li>';
//		    populateDB();
	        };
            };
	};

 	function randString(len) {
	    var ret = "";
	    for(var i=0; i<len; i++)
		ret += ALPHA.charAt(Math.floor(Math.random() * ALPHA.length + 0.5));
	    return ret;
	}

        function write2DB(db, store) {
	    note.innerHTML = '';
            var transaction = data[db].transaction(store, "readwrite");
            transaction.oncomplete = function(e) { note.innerHTML += '<li> RW transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> RW transaction error:' + e.target.errorCode + '. </li>' };
            
            var objStore = transaction.objectStore(store);
            return objStore;
        }
        
        function readDB(db, store) {
	    note.innerHTML = '';
            var transaction = data[db].transaction(store);
            transaction.oncomplete = function(e) { note.innerHTML += '<li> Read transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> Read transaction error:' + e.target.errorCode + '. </li>' };
            
            return transaction.objectStore(store);
        }

	function clearDB() {
	    var db = DB_BAG;
	    var store = DB_STORE_BAG;
	    var objStore = write2DB(db, store);
	    var req = objStore.clear();
	    req.onsuccess = function() { note.innerHTML = '<li> Data cleared. </li>' };
	}

	function reloadDB() {
	    var db = DB_DATA;
	    var store = DB_STORE_DATA;
	    clearDB(db, store);
	    populateDB();
	}

	function countDB() {
	    var db = DB_BAG;
	    var store = DB_STORE_BAG;
	    var objStore = readDB(db, store);
	    var req = objStore.count();
	    req.onsuccess = function() { note.innerHTML = '<li> Count: ' + req.result + '</li>'; }
	}
 
        function populateDB() {
	    var db = DB_DATA;
	    var store = DB_STORE_DATA;
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
                    
                    var objStore = write2DB(db, store);
                    for (var i in datos) { objStore.add( asobj(datos[i]) ); }
                    
                    note.innerHTML = '<li> Data loaded to DB. </li>';
                }
            };
            xhttp.send(null);
        }

	function search(s) {
	    document.getElementById('resultados').style.visibility='visible';
//	    ans.innerHTML = '';
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
	    var req = readDB(DB_DATA, DB_STORE_DATA).get( asnum(s) );
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
            var index = readDB(DB_DATA, DB_STORE_DATA).index("desc");
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

	function add2bag(e) {
	    resultados.style.visibility='hidden';
	    ans.innerHTML = '';
	    if (hideBag) {
		document.getElementById('ticket').style.visibility='visible';
		hideBag = false;
	    }
	    
	    var clave = asnum( e.target.parentElement.dataset.clave );
	    console.log('Click on me: '+clave);

	    var newTicket = { uid: randString(STRLEN), fecha: '', version: 1.0, items: {} };
	    newTicket.items[clave] = { qty: 1, precio: 'precio1', rea: 0, version: 1, total: 0 };
	    var objStore = write2DB( DB_BAG, DB_STORE_BAG );
	    objStore.add( newTicket );
 
	    var req = readDB(DB_DATA, DB_STORE_DATA).get( clave );
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

