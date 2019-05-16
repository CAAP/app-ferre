	var facturas = {
	    xget: (q,o) => XHR.get( facturas.origin + q + '?' + UTILS.asstr(o) )
	};

