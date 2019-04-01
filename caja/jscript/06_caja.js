	var caja = {
	    UPDATED: false,
	    UIDS: new Set(),
	    updateItem: e => { caja.UPDATED = true; return TICKET.update(e); },
	    clickItem: e => { caja.UPDATED = true; return TICKET.remove( e.target.parentElement ); },
	    xget: (q,o) => XHR.get( caja.origin + q + '?' + UTILS.asstr(o) )
	};
