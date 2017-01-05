	"use strict";

	var IDB = {

	    indexedDB: (window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB),

	    loadDB: function(k) {
		return new Promise( (resolve, reject) => {
		    let req = IDB.indexedDB.open(k.DB, k.VERSION);
		    req.onerror = e => reject( 'Error loading database: ' + k.DB + ' | ' + e.target.errorCode );
	            req.onsuccess = function(e) { k.CONN = e.target.result; resolve( k ); };
		    req.onupgradeneeded = function(e) {
			let conn = e.target.result;
			function upgrade( kk ) {
			    let objStore = conn.createObjectStore(kk.STORE, { keyPath: kk.KEY });
			    if (kk.INDEX) { kk.INDEX.forEach( idx => objStore.createIndex(idx.name||idx.key, idx.key, {unique: false}) ) }
			    console.log('ObjectStore ' + kk.STORE + ' created successfully.');
			}

			console.log('Upgrade ongoing.');
			k.STORES.forEach(upgrade);
			k.CONN = conn;
			conn.transaction.oncomplete = () => resolve( k );
		    };
		} );
	    },

	    populateDB: function(k) {
		function asobj(a, ks) {
		    let ret = {};
		    for (let i in ks) { ret[ks[i]] = a[i]; }
		    return (k.MAP ? k.MAP(ret) : ret);
		}

		function store(objsto) {
		    let ks = objsto[0], datos = objsto[1];
		    let os = IDB.write2DB(k);
		    return Promise.all( datos.map( dato => os.add(asobj(dato, ks)) ) );
		}

		function getVers() {
		    if (k.VERS) {
			return XHR.getJSON( k.VERS ).then( o => { localStorage.vers = o.vers; localStorage.week = o.week; } );
		    }
		}

		return XHR.getJSON( k.FILE ).then( store ).then( () => console.log("Datos loaded to store " + k.STORE) ).then( getVers );
	    },

	    clearDB: k => IDB.write2DB(k).clear(),

	    recreateDB: k => IDB.clearDB(k).then( IDB.populateDB )
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
		this.countIndex = function(range) {return new Promise( (resolve, reject) => {
		    let request = os.index( k.INDEX ).count(range);
		    request.onsuccess = () => resolve( request.result );
		    request.onerror = () => reject( request.errorCode ); })};
		this.index = function(range, type, f) { return new Promise( (resolve, reject) => {
		    let request = os.index( k.INDEX ).openCursor(range, type);
		    request.onsuccess = () => resolve( f(request.result) );
		    request.onerror = () => reject( request.errorCode ); })};
	    }

	    IDB.readDB = function( k ) { return new ObjStore(k.CONN.transaction(k.STORE, "readonly").objectStore(k.STORE), k); };

	    IDB.write2DB = function( k ) {
		let objStore = k.CONN.transaction(k.STORE, "readwrite").objectStore(k.STORE);
		let os = new ObjStore( objStore, k );
		os.clear = function() { return new Promise( (resolve, reject) => {
		    let request = objStore.clear();
		    request.onsuccess = resolve(k);
		    request.onerror = reject(event.target.errorCode);
		})};
		os.delete = function(w) { return new Promise( (resolve, reject) => {
		    let request = objStore.delete(w);
		    request.onsuccess = resolve(true);
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
