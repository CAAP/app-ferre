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
		    INDEX: [{key: 'desc'}]
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
		return os.get( o.clave ).then( q => {if (q) {return Object.assign(q, o);} else {return o;} } )
		    .then( asprice )
		    .then( os.put );
	    }

	    const PRICE = DATA.STORES.PRICE;
	    PRICE.MAP = asprice;
	    PRICE.upgrade = upgrade;
	    PRICE.update = o => {
		if (o.desc && o.desc.startsWith('VV'))
		    return IDB.write2DB( PRICE ).delete( o.clave );
		return upgrade( o ).then( DATA.inplace );
	    };

	})();

	// onLoaded
	(function() {
	    let lvers = document.getElementById('db-vers');

	    DATA.STORES.VERS.update = o => {
		localStorage.vers = o.vers;
		localStorage.week = o.week;
		lvers.textContent = ' | ' + o.week + 'V' + o.vers;
	    };

	})();

	// onEventSource
	(function(esource) {
	    UTILS.forObj(STORES, store => {STORES[store].CONN = DATA.CONN});

	})();


	(function() {
	    //  XXX New feature some browsers only
	    DATA.ppties -> UTILS.ppties //XXX

	    DATA.encPpties -> UTILS.encPpties // XXX

	    DATA.close = e => e.target.closest('dialog').close(); // XXX where is it USED?
	})();

	DATA.onLoaded = esrc => {

	    let updateMe = data => Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) ); // XXX Needed???


		esrc.addEventListener('update', e => {
		    const data = JSON.parse(e.data);
		    const upd = data.find(o => {return o.store == 'VERS'});

// XXX Need to address issue of already registered from admin et al.
// XXX What happends if upd.prev < localStorage.vers
		    if (localStorage.week && upd.week == localStorage.week && upd.prev == localStorage.vers) {
			console.log(upd.vers == localStorage.vers?'Already up-to-date.':'Update event ongoing!');
// XXX if (upd.vers != localStorage.vers) // gets me the version on the footer
			    updateMe( data );
		    } else {
			console.log('Update mismatch error: ' + localStorage.week + '(' + upd.week + ') V' + localStorage.vers + '(V' + upd.vers + ')');
			XHR.getJSON('/app/updates.lua?oweek='+localStorage.week+'&overs='+localStorage.vers+'&nweek='+upd.week).then( updateMe );
		    }
		}, false);


	};

