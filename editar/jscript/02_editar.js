	var editar = {
	    xget: (q,o) => XHR.get( editar.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( editar.origin + q, UTILS.asstr(o) )
	};
