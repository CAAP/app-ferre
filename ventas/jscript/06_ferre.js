	var ferre = {
	    PINS: new Map(),
	    updateItem: TICKET.update,
//	    clickItem: e => TICKET.remove( e.target.parentElement ),
	    xget: (q,o) => XHR.get( ferre.origin + q + '?' + UTILS.asstr(o) ),
	    xpost: (q, o) => XHR.post( ferre.origin + q, UTILS.asstr(o) )


	    guardar: function temporal(s) {
		const PRICE = DATA.STORES.PRICE;
		let ret = [];
		IDB.readDB( PRICE ).openCursor(cursor => {
		if (cursor) {
		    let a = cursor.value;
		    ret.push( a );
		    cursor.continue();
		} else {
		    let b = new Blob([JSON.stringify(ret)], {type: 'application/json'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'datos.json'
		    a.click();
		    URL.revokeObjectURL(url);
		} });
	    }

	};

	(function() {
	    TICKET.lookUp = true;
	})();
