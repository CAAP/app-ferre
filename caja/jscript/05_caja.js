	var caja = {
	    UPDATED: false,
	    OLD: false,
	    RFC: null,
	    UIDS: new Set(),
	    NAMES: new Map(),
	    xget: (q,o) => XHR.get( caja.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( caja.origin + q, UTILS.asstr(o) )
	};

	(function() {
//	    let old_update = TICKET.update;
	    let old_remove = TICKET.remove;
//	    TICKET.update = e => { caja.UPDATED = true; return old_update(e); };
	    TICKET.remove = e => { caja.UPDATED = true; return old_remove(e); };
//	    caja.updateItem = TICKET.update;
	})();

