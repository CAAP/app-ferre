
        "use strict";

        const DB_NAME = 'datos';
        const DB_VERSION = 2;
        const DB_STORE_NAME = 'datos-clave';
        
        var note;
        var ans;
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
       
        function searchByDesc(s) {
	    ans.innerHTML = '';

            var index = readDB().index("desc");
            var descRange = IDBKeyRange.lowerBound(s);
	    var k = 0;
            index.openCursor( descRange ).onsuccess = function(e) {
                var cursor = e.target.result;
                if (cursor) {
                    var item = '<tr name="clave" onclick="myname(event)">' + '<td>' + cursor.value.fecha + "</td><td>" + cursor.value.desc + "</td><td>" + cursor.value.precio1 + "</td><td>" + cursor.value.u1 + "</td>";
		    item += cursor.value.precio2>0 ? "<td>"+cursor.value.precio2+"</td><td>"+cursor.value.u2+"</td>": '<td></td><td></td>';
		    item += '</tr>';
                    ans.innerHTML += item;
		    k++;
		    if (k == 20) { return; }
                    cursor.continue();
                }
            };
        }
 
	window.onload = function() {
            note = document.getElementById('notifications');
            ans = document.getElementById('tabla-resultados');

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
            searchByDesc(e.target.value);
            e.target.value = "";
        }
        
        function keyPressed(e) {
            if (e.key == 'Escape') {
                e.target.value = "";
            }
        }

	function scrolling(e) {
	    console.log('Scrolling by: '+e.target.name);
	}

	function myname(e) {
	    console.log('Click on me: '+e.target.parentElement);
	}

