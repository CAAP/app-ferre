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
			    const oo = k.STORES[kk];
			    if (oo.STORE == undefined) { return; }
			    let objStore = conn.createObjectStore(oo.STORE, { keyPath: oo.KEY });
			    if (oo.INDEX) { oo.INDEX.forEach( idx => objStore.createIndex(idx.name||idx.key, idx.key, {unique: false}) ) }
			    console.log('ObjectStore ' + oo.STORE + ' created successfully.');
			}

			console.log('Upgrade ongoing.');
			UTILS.forObj(k.STORES, upgrade) //k.STORES.forEach(upgrade);
			k.CONN = conn;
			conn.transaction.oncomplete = () => resolve( k );
		    };
		} );
	    },

	    populateDB: function(k) {

		function getVers(datos) {
		    let v = false;
		    if (typeof(datos[datos.length-1]["version"]) != "undefined" ) {
			v = datos.pop();
		    }
		    return v;
		}

		function store(datos) {
		    let os = IDB.write2DB(k);
		    let v = getVers(datos);
		    return Promise.all( datos.map( obj => os.add(k.MAP ? k.MAP(obj) : obj) ) )
				.then( () => Promise.resolve(true) ).then( () => Promise.resolve(v) );
		}

		return XHR.getJSON( k.FILE )
			    .then( store )
			    .then( v => { console.log("Datos loaded to store "+k.STORE); return Promise.resolve(v); } );
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
		this.getIndex = function(v) {return new Promise( (resolve, reject) => {
		    let request = os.index( k.INDEX ).get(v);
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
