	var admin = {
	    xget: (q,o) => XHR.get( admin.origin + q + '?' + UTILS.asstr(o) )
	};
