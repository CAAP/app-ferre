	var ferre = {
	    MISS: false,
	    PINS: new Map(),
	    updateItem: TICKET.update,
//	    clickItem: e => TICKET.remove( e.target.parentElement ),
	    xget: (q,o) => XHR.get( ferre.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( ferre.origin + q, UTILS.asstr(o) )
	};

	(function() {
	    TICKET.lookUp = true;
	})();
