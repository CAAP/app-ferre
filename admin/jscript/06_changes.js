	var CHANGES = {};

	(function() {
	    let cambios = new Map();

	    CHANGES.get = (k, f) => { if (cambios.has(k)) { return f(k, cambios.get(k)) } return Promise.reject('No changes for key: ' + k ); };

	    CHANGES.fetch = (k, a) => { return (cambios.has(k) ? Object.assign({}, a, cambios.get(k)) : a)};

	    CHANGES.inplace = (k, f) => { if (cambios.has(k) { Object.keys(cambios.get(k)).forEach(f); } };

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

	})();
