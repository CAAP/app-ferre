	var DATA = {
	    VERSION: 1,
	    DB: 'datos',
	    STORES: {
		PRICE: {
		    STORE: 'precios',
		    KEY: 'clave',
		    FILE: '/json/precios.json',
		    VERS: '/json/version.json',
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

	    const PRICE = DATA.STORES.PRICE;

	    function upgrade(o) {
		let os = IDB.write2DB( PRICE );
		return os.get(o.clave).then(q => {if (q) {return Object.assign(q, o);} else {return o;} })
		    .then( asprice )
		    .then( os.put );
	    }

	    PRICE.MAP = asprice;
	    PRICE.update = o => {
		if (o.desc && o.desc.startsWith('VV'))
		    return IDB.write2DB( PRICE ).delete( o.clave );
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

