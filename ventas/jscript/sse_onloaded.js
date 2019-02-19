
	// Init & Load DBs
	(function() {
	    const STORES = DATA.STORES;
	    let lvers = document.getElementById('db-vers');
	    STORES.VERS.update = o => {
		localStorage.vers = o.vers;
		localStorage.week = o.week;
		lvers.textContent = ' | ' + o.week + 'V' + o.vers;
	    };

	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
		    return IDB.populateDB(k)
			      .then(() => XHR.getJSON(k.VERS))
			      .then(o => {localStorage.vers = o.vers; localStorage.week = o.week;});
		     }
	        );
	    }

	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then(db => Promise.all( STORES.map(store => {store.CONN = db.CONN; return ifLoad(store);}) ));
	})();

	// fetch, update VERSION
	(function() {
	    const origin = UTILS.origin;
	    const week = localStorage.week;
	    const vers = localStorage.vers;
		// current WEEK, VERS

	    if (WEEK != week || VERS != vers) {
		console.log('Version mismatch: '+WEEK+' ('+week+'), V'+VERS+' (V'+vers+')');
		XHR.getJSON(origin+':5040/update?oweek='+week+'&overs='+vers+'&nweek='+WEEK)
			.then( updateMe );
	    }
	})();

	// connect DATA's EVENT-SOURCE
	(function(esource) {
	    const origin = UTILS.origin;
	    const STORES = DATA.STORES;

	    let updateMe = data => Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) );

	    let esource = new EventSource(origin + ":5030");

	    esource.addEventListener('update', e => {
		const week = localStorage.week;
		const vers = localStorage.vers;
		const data = JSON.parse(e.data);
		const upd = data.find(o => {return o.store == 'VERS'});
		console.log('Update event ongoing!');
		if (upd.week == week && upd.prev == vers)
		    updateMe(data);
	    }, false);
	})();


	(function() {

	    function a2obj( a ) {
		const M = a.length/2;
		let o = {};
		for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; }
		return o;
	    }




//		    DATA.onLoaded(esource);	XXX
		esource.addEventListener("tabs", function(e) {
		    console.log("tabs event received.");
		    JSON.parse( e.data ).forEach( o => PEOPLE.tabs.set(o.pid, o.query.split('&').map(s => a2obj(s.split('+')))) );  //data(a2obj(s.split('+'))))
		}, false);
		esource.addEventListener("delete", function(e) {
		    const pid = Number(e.data);
		    PEOPLE.tabs.delete(pid);
		    console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		}, false);

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( addEvents );
	    })();

