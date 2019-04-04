	var admin = {
	    cambios: new Map(),
	    updateItem: e => { caja.UPDATED = true; return TICKET.update(e); },
	    clickItem: e => { caja.UPDATED = true; return TICKET.remove( e.target.parentElement ); },
	    xget: (q,o) => XHR.get( admin.origin + q + '?' + UTILS.asstr(o) )
	};
