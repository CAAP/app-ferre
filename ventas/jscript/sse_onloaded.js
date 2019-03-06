	// SSE - ServerSentEvent's
	(function() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const tabs = ferre.TABS;

		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }

		function distill( s ) {
		    let chunks = s.split('&query=');
		    const pid = Number( chunks.shift().match(/\d+/) );
		    tabs.set(pid, chunks.map(s => a2obj(s.split('+'))));
		}

		esource.addEventListener("Hi", function(e) {
		    elbl.innerHTML = "Hi from "+e.data;
		    console.log(e.data);
		}, false);

		esource.addEventListener("Bye", function(e) {
		    elbl.innerHTML = "Bye from "+e.data;
		    console.log(e.data);
		}, false);

		esource.addEventListener("fruit", function(e) {
		    console.log(e.data);
		    localStorage.fruit = e.data;
		    flbl.innerHTML = e.data;
		    XHR.get( ferre.origin + 'CACHE?' + e.data );
		}, false);

		esource.addEventListener("version", function(e) {
		    if (!DATA.STORES.VERS.check( JSON.parse(e.data) ))
			ferre.xget('adjust', localStorage); // adjust version-time
		    elbl.innerHTML = "version event";
		}, false);

		esource.addEventListener("delete", function(e) {
		    const pid = Number( e.data );
		    tabs.delete( pid );
		    console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    elbl.innerHTML = "delete event";
		}, false);

		esource.addEventListener("tabs", function(e) {
		    console.log("tabs event received.");
		    elbl.innerHTML = "tabs event";
		    distill( e.data );
		}, false);

		esource.addEventListener("precios", function(e) {
		    const o = JSON.parse(e.data);
		    elbl.innerHTML = "precios event";
		}, false);

	})();


/*
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
*/

/*
	// connect DATA's EVENT-SOURCE
	(function() {
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
*/

/*
	(function() {
	    function a2obj( a ) {
		const M = a.length/2;
		let o = {};
		for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; }
		return o;
	    }

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
*/

