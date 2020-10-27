	var DATA = {
	    VERSION: 1,
	    DB: 'datos',
	    STORES: {
		PRICE: {
		    STORE: 'precios',
		    KEY: 'clave',
		    FILE: '/json/precios.json',
		    INDEX: [{key: 'desc'}] // {key: 'faltante'}, {key: 'proveedor'}
		},
		VERS: {},
		CUSTOMERS: {
		    STORE: 'clientes',
		    KEY: 'rfc',
		    FILE: '/json/clientes.json',
		    INDEX: [{key: 'razonSocial'}, {key: 'rfc'}]
		}
	    }
	};


	(function() {
	    function asprice(q) {
		q.precios = {};
		for (let i=1; i<4; i++) {
		    let k = 'precio'+i;
		    if (q[k] > 0) {
			let uu = String(q['u'+i] || '');
			uu = uu.substring(uu.search(/_/)+1);
			q.precios[k] = q[k].toFixed(2) + ' / ' + uu;
		    }
		}
		return q;
	    }

	    const PRICE = DATA.STORES.PRICE;
	    const UU = ['u1', 'u2', 'u3'];
	    const asnum = UTILS.asnum;

	    function upgrade(o) {
		let os = IDB.write2DB( PRICE );
		UU.forEach( u => { if (o[u]) { o[u] = o[u].substring(o[u].search(/_/)+1); } } );
		return os.get( asnum(o.clave) ).then(q => {if (q) {return Object.assign(q, o);} else {return o;} })
		    .then( asprice )
		    .then( os.put );
	    }

	    PRICE.MAP = asprice;
	    PRICE.update = o => {
		if (o.desc && o.desc.startsWith('VV'))
		    return IDB.write2DB( PRICE )
			    .delete( asnum(o.clave) )
			    .then( DATA.inplace );
		return upgrade( o ).then( DATA.inplace );
	    };

	    const VERS = DATA.STORES.VERS;
	    VERS.check = o => {
		if (!localStorage.week) // XXX WTF! should never happen!
		    return true;
		if (localStorage.week == o.week && localStorage.vers == o.vers)
		    return VERS.inplace(o);
		if (localStorage.week == o.week && localStorage.vers < o.vers)
		    return false;
	    };
	    VERS.update = o => {
		localStorage.vers = o.vers;
		localStorage.week = o.week;
		return Promise.resolve( o ).then( VERS.inplace );
	    };

	})();

