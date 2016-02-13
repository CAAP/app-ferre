	"use strict";

	var IDB = {

	    indexedDB: (window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB),

	    loadDB: function(k) {
		let req = IDB.indexedDB.open(k.DB, k.VERSION);
		req.onerror = e => console.log('Error loading database: ' + k.DB + ' | ' + e.target.errorCode);
	        req.onsuccess = function(e) { k.CONN = e.target.result; if (k.load) { k.load(); }};
		req.onupgradeneeded = function(e) {
		    console.log('Upgrade ongoing.');
		    let objStore = e.target.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		    if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
		    objStore.transaction.oncomplete = function(ev) {
			console.log('ObjectStore ' + k.STORE + ' created successfully.');
			if (k.FILE) { IDB.populateDB( k ); }
			if (k.load) { k.load(); };
		    };
		};
	    },

	    populateDB: function(k) {
		function asobj(a, ks) {
		    let ret = {};
		    for (let i in ks) { ret[ks[i]] = a[i]; }
		    return ret;
		}
		function store(objsto) {
		    let ks = objsto[0], datos = objsto[1];
		    let os = IDB.write2DB(k);
		    return datos.map( dato => os.add(asobj(dato)) )
			.reduce( (seq, p) => seq.then( () => p ), Promise.resolve() );
		}
		XHR.getJSON( k.FILE ).then( store ).then( () => console.log("Datos loaded to DB " + k.DB) );
	    },

	    clearDB: k => IDB.write2DB(k).clear()
	};

	(function() {

	    function ObjStore(objStore, k) {
		let os = objStore;
		this.count = function() { return new Promise( (resolve, reject) => {
		    let request = os.count();
		    request.onsuccess = function() { resolve( request.result ); };
		    request.onerror = () => reject( request.errorCode ); })};
		this.get = function(k) { return new Promise( (resolve, reject) => {
		    let request = os.get(k);
		    request.onsuccess = function() { resolve( request.result ); };
		    request.onerror = () => reject( request.errorCode ); })};
		this.openCursor = function(f) { return new Promise( (resolve, reject) => {
		    let request = os.openCursor();
		    request.onsuccess = () => resolve( f(request.result) );
		    request.onerror = () => reject( request.errorCode ); })};
		this.index = function(range, type, f) { return new Promise( (resolve, reject) => {
		    let request = os.index( k.INDEX ).openCursor(range, type);
		    request.onsuccess = () => resolve( f(request.result) );
		    request.onerror = () => reject( request.errorCode ); })};
	    }

	    IDB.readDB = function( k ) { return new ObjStore(k.CONN.transaction(k.STORE, "readonly").objectStore(k.STORE), k); };

	    IDB.write2DB = function( k ) {
		let objSto = k.CONN.transaction(k.STORE, "readwrite").objectStore(k.STORE);
		let os = new ObjStore( objSto, k );
		os.clear = function() { return new Promise( (resolve, reject) => {
		    let request = objStore.clear();
		    request.onsuccess = function() { resolve( os ); };
		    request.onerror = reject(event.target.errorCode);
		})};
		os.add = function(q) { return new Promise( (resolve, reject) => {
		    let request = objStore.add(q);
		    request.onsuccess = resolve(q);
		    request.onerror = reject(event.target.errorCode);
		})};
		os.put = function(q) { return new Promise( (resolve, reject) => {
		    let request = objStore.put(q);
		    request.onsuccess = resolve(q);
		    request.onerror = reject(event.target.errorCode);
		})};
		return os;
	    };

	})();
