	"use strict";

	var IDB = {

	    indexedDB: (window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB),

	    loadDB: function(k) {
		let req = this.indexedDB.open(k.DB, k.VERSION);
		req.onerror = e => console.log('Error loading database: ' + k.DB + ' | ' + e.target.errorCode);
	        req.onsuccess = function(e) { k.CONN = e.target.result; if (k.load) { k.load(); }};
		req.onupgradeneeded = function(e) {
		    console.log('Upgrade ongoing.');
		    let objStore = e.target.result.createObjectStore(k.STORE, { keyPath: k.KEY });
		    if (k.INDEX) { objStore.createIndex(k.INDEX, k.INDEX, { unique: false } ) }
		    objStore.transaction.oncomplete = function(ev) {
			console.log('ObjectStore ' + k.STORE + ' created successfully.');
			if (k.FILE) { IDB.populateDB( k ); }
		    };
		};
	    },

	    clearDB: function(k) {
		let req = this.write2DB(k).clear();
		req.onsuccess = function() { console.log( 'Data cleared from DB; ' + k.DB ); };
	    },
	};

	(function() {

	function Request(url, options) {
	    return new Promise((resolve, reject) => {
	        let xhr = new XMLHttpRequest;
	        xhr.onload = event => resolve(event.target);
	        xhr.onerror = reject;

	        let defaultMethod = options.data ? "POST" : "GET";

	        if (options.mimeType)
	            xhr.overrideMimeType(params.options);

	        xhr.open(options.method || defaultMethod, url);

	        if (options.responseType)
	            xhr.responseType = options.responseType;

	        for (let header of Object.keys(options.headers || {}))
	            xhr.setRequestHeader(header, options.headers[header]);

	        let data = options.data;
	        if (data && Object.getPrototypeOf(data).constructor.name == "Object") {
	            options.data = new FormData;
	            for (let key of Object.keys(data))
	                options.data.append(data[key]);
	        }

	        xhr.send(options.data);
	    });
	}

	    function asobj(a, ks) {
		let ret = {};
		for (let i in ks) { ret[ks[i]] = a[i]; }
		return ret;
	    }

	    IDB.populateDB = function(k) {
		new Request(k.FILE, { responseType: 'json' })
		    .then(response => {
			let data = JSON.parse( response.responseText );
			let ks = data[0], datos = data[1];
			let objStore = IDB.write2DB( k );
			datos.map( x => objStore.add(asobj(x, ks)) );
			console.log('Data loaded to DB: '+k.DB);});
	    };

	    function transaction(t) {
		return function initTransaction( k ) {
		    let trn = k.CONN.transaction(k.STORE, t);
		    trn.oncomplete = function(e) { console.log(t +' transaction successfully done.'); };
		    trn.onerror = function(e) { console.log( t + ' transaction error:' + e.target.errorCode); };
		    return trn.objectStore(k.STORE);
		};
	    };

	    IDB.write2DB = transaction("readwrite");

	    IDB.readDB = transaction("readonly");

	})();
