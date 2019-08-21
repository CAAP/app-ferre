	var caja = {
	    UPDATED: false,
	    UIDS: new Set(),
	    updateItem: TICKET.update,
//	    clickItem: e => { caja.UPDATED = true; return TICKET.remove( e.target.parentElement ); },
	    xget: (q,o) => XHR.get( caja.origin + q + '?' + UTILS.asstr(o) )
	};

	(function() {
	    let old_update = TICKET.update;
	    TICKET.update = e => { caja.UPDATED = true; return old_update(e); };
	})();

