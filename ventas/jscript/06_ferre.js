	var ferre = {
	    PINS: new Map(),
	    updateItem: TICKET.update,
//	    clickItem: e => TICKET.remove( e.target.parentElement ),
	    xget: (q,o) => XHR.get( ferre.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( ferre.origin + q, UTILS.asstr(o) ),
	};

	(function() {
	    TICKET.lookUp = true;
	    let UNITS = new Map();
	    XHR.getJSON('/json/units.json').then(a => a.forEach( u => UNITS.set(u.unidad, u) ));
	    ferre.tips = (e, q) => {
		if (q.includes('/')) {
		    const l = q.substring(q.search(/\//)+2).trim();
		    e.title = UNITS.has(l) ? UNITS.get(l).desc : '?';
		}
	    };

	})();
