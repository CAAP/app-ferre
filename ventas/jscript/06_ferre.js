	var ferre = {
	    updateItem: TICKET.update,
//	    clickItem: e => TICKET.remove( e.target.parentElement ),
	    xget: (q,o) => XHR.get( ferre.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( ferre.origin + q, UTILS.asstr(o) )
	};
