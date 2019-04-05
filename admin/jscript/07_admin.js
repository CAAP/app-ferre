	var admin = {
	    cambios: new Map(),
	    xget: (q,o) => XHR.get( admin.origin + q + '?' + UTILS.asstr(o) )
	};
