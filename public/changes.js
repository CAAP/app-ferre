        "use strict";

	var CHANGES = {};

	(function() {
	    let cambios = new Map();
//	    let records = new Map();

/*	    CHANGES.fetch = function(k, url, f) {
		if (records.has(k)) { return f(cambios.has(k) ? Object.assign({}, records.get(k), cambios.get(k)) : records.get(k)); }
		return XHR.getJSON(url).then(a => { records.set(k, a[0]); f(a[0]);});
	    }; */

	    CHANGES.get = (k,f) => { if (cambios.has(k)) { return f(k, cambios.get(k)); } return Promise.reject('No changes for key: '+k); }

	    CHANGES.fetch = function(k, a) { return (cambios.has(k) ? Object.assign({}, a, cambios.get(k)) : a); }

	    CHANGES.inplace = function(k, f) { if (cambios.has(k)) { Object.keys(cambios.get(k)).forEach(f); } };

	    CHANGES.update = (clave, k, v) => {
		if (cambios.has(clave)) {
		    let b = cambios.get(clave);
		    b[k] = v;
		    cambios.set(clave, b);
		} else {
		    let a = {}; a[k] = v;
		    cambios.set(clave, a);
		}
	    };

	    CHANGES.clear = () => cambios.clear();

//	    CHANGES.rawset = (k, f) => records.set(k, f(records.get(k)));

	    CHANGES.curry = function(f) {
		let ret = [];
		cambios.forEach( o => ret.push( f(o) ) );
		return ret;
	    };
	})();
