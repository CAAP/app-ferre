	var admin = {
	    cambios: new Map(),
	    xget: (q,o) => XHR.get( admin.origin + q + '?' + UTILS.asstr(o) ),

	    guardar: function temporal(s) {
		const PRICE = DATA.STORES.PRICE;
		let ret = [];
		IDB.readDB( PRICE ).openCursor(cursor => {
		if (cursor) {
		    let a = cursor.value;
		    ret.push( a.clave + '\t' + a.desc + '\t' + (a.costol / 1e4).toFixed(2) + '\t' + a.proveedor + '\t' + a.uidPROV );
--		    ret.push( a.clave + '\t' + a.desc + '\t' + a.proveedor + '\t' + (a.costol / 1e4).toFixed(2) );
		    cursor.continue();
		} else {
		    let b = new Blob([ret.join('\n')], {type: 'text/html'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'ListaPrecios.tsv'
		    a.click();
		    URL.revokeObjectURL(url);
		} });
	    }

	};
