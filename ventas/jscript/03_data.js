	var DATA = {
	    VERSION: 1,
	    DB: 'datos',
	    clearTable: tb => { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } },
	    asstr: o => {
		if (Array.isArray(o))
		    return o.join('&');
// 	   fn ppties could be use instead XXX 
		let props = [];
		for (var prop in o) { props.push( prop + '=' + o[prop] ); }
		return props.join('&');
	    },
	    STORES: {
		PRICE: {
		    STORE: 'precios',
		    KEY: 'clave',
		    FILE: '/ventas/json/precios.json',
		    VERS: '/ventas/json/version.json',
		    INDEX: [{key: 'desc'}] // {key: 'faltante'}, {key: 'proveedor'}
		},
		VERS: {}
	    }
	};

	(function() {
	    function asprice(q) {
		q.precios = {};
		for (let i=1; i<4; i++) {
		    let k = 'precio'+i;
		    if (q[k] > 0)
			q.precios[k] = q[k].toFixed(2) + ' / ' + q['u'+i];
		}
		return q;
	    }

	    function upgrade(o) {
		let os = IDB.write2DB( PRICE );
		return os.get(o.clave).then(q => {if (q) {return Object.assign(q, o);} else {return o;} })
		    .then( asprice )
		    .then( os.put );
	    }

	    const PRICE = DATA.STORES.PRICE;
	    PRICE.MAP = asprice;
	    PRICE.update = o => {
		if (o.desc && o.desc.startsWith('VV'))
		    return IDB.write2DB( PRICE ).delete( o.clave );
		return upgrade( o ).then( DATA.inplace );
	    };
	})();

