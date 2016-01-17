
        "use strict";

        const DB_NAME = 'datos';
        const DB_VERSION = 2;
        const DB_STORE_NAME = 'datos-clave';
	const TODAY = new Date().toDateString();
        
        var note, bag, ans;
        var data = {};
        var IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;

        function write2DB() {
	    note.innerHTML = '';
            var transaction = data.datos.transaction(DB_STORE_NAME, "readwrite");
            transaction.oncomplete = function(e) { note.innerHTML += '<li> RW transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> RW transaction error:' + e.target.errorCode + '. </li>' };
            
            var objStore = transaction.objectStore(DB_STORE_NAME);
            return objStore;
        }
        
        function readDB() {
	    note.innerHTML = '';
            var transaction = data.datos.transaction(DB_STORE_NAME);
            transaction.oncomplete = function(e) { note.innerHTML += '<li> Read transaction successfully done. </li>' };
            transaction.onerror = function(e) { note.innerHTML += '<li> Read transaction error:' + e.target.errorCode + '. </li>' };
            
            return transaction.objectStore(DB_STORE_NAME);
        }

	function clearDB() {
	    var objStore = write2DB();
	    var req = objStore.clear();
	    req.onsuccess = function() { note.innerHTML = '<li> Data cleared. </li>' };
	}

	function reloadDB() {
	    clearDB();
	    populateDB();
	}

	function countDB() {
	    var objStore = readDB();
	    var req = objStore.count();
	    req.onsuccess = function() { note.innerHTML = '<li> Count: ' + req.result + '</li>'; return req.result; }
	}
 
        function populateDB() {
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
                    
                    var objStore = write2DB();
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
            var item = '<tr id="' + a.clave + '"><td>' + a.fecha + '</td><td>' + a.desc + "</td><td>" + a.precio1 + "</td><td>" + a.u1 + "</td>";
	    item += a.precio2>0 ? "<td>"+a.precio2+"</td><td>"+a.u2+"</td>": '<td></td><td></td>';
	    item += '</tr>';
	    return item;
	}

	function asnum(s) {
	    var n = Number(s);
	    return Number.isNaN(n) ? s : n;
	}

        function searchByClave(s) {
	    console.log('Searching by clave.');
	    var req = readDB().get( asnum(s) );
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
            var index = readDB().index("desc");
            var descRange = IDBKeyRange.lowerBound(s);
	    var k = 0;
            index.openCursor( descRange ).onsuccess = function(e) {
                var cursor = e.target.result;
                if (cursor) {
                    ans.innerHTML += newItem(cursor.value);
		    k++;
		    if (k == 20) { return; }
                    cursor.continue();
                }
            };
        }
 
	window.onload = function() {
            note = document.getElementById('notifications');
            ans = document.getElementById('tabla-resultados');
	    bag = document.getElementById('ticket-compra');

	    var indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;

            var req = indexedDB.open(DB_NAME, DB_VERSION);
            req.onerror = function(e) { note.innerHTML = '<li>Error loading database: '+ e.target.errorCode + '. </li>'; };
            req.onsuccess = function(e) { note.innerHTML = '<li>Database initialized.</li>'; data.datos = this.result; };
            req.onupgradeneeded = function(e) {
                note.innerHTML = '<li>Upgrade ongoing.</li>';
                
                var objStore = e.currentTarget.result.createObjectStore(DB_STORE_NAME, { keyPath: "clave" });
                objStore.createIndex("desc", "desc", { unique: false } );
                objStore.transaction.oncomplete = function(e) {
                    note.innerHTML = '<li> ObjectStore created. Ready to add data into it. </li>';
		    populateDB();
                }

            };
        };

        function inputChange(e) {
            search(e.target.value);
            e.target.value = "";
        }
        
        function keyPressed(e) {
            if (e.key == 'Escape') {
                e.target.value = "";
            }
        }

	function changedEvent(e) { console.log('Value: ' + e.target.innerHTML); }

	function add2bag(e) {
	    document.getElementById('ticket').style.visibility='visible';

	    var id = e.target.parentElement.id;
	    console.log('Click on me: '+id);

	    var req = readDB().get( asnum(id) );
	    req.onsuccess = function(ev) {
		var q = ev.target.result;
		bag.innerHTML += '<tr><td><label contentEditable=true>1</label></td><td>'+q.desc+'</td><td>'+q.precio1+' '+q.u1+'</td><td contentEditable=true>0</td></tr>';
	    }
	}

