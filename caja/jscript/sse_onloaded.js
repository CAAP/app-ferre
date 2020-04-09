	// SSE - ServerSentEvent's
	(function ssevent() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById('eventos');
	    const flbl = document.getElementById('frutas');
	    const tlbl = document.getElementById('taxes');
	    const STORES = DATA.STORES;

	    const add2caja  = caja.add2caja;
	    const add2bag   = caja.add2bag;
	    const add2fecha = caja.add2fecha;

	    const spin = document.getElementById('pacman');

		function ready() { spin.style.visibility = 'hidden'; }

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		esource.onerror = () => { spin.style.visibility = 'visible' };

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    if (e.data.match(/[a-z]+/)) {
			let fruit = e.data;
			console.log('I am ' + fruit);
			sessionStorage.fruit = fruit;
			flbl.innerHTML = fruit;
			ready();
			XHR.get( caja.origin + 'CACHE?' + fruit );
			XHR.get( caja.origin + 'feed?' + fruit );
		    } else {
			esource.close();
			ssevent();
		    }
		}, false);

		esource.addEventListener("Hi", function(e) {
		    elbl.innerHTML = "Hi from "+e.data;
		    console.log('Hi from ' + e.data);
		}, false);

		esource.addEventListener("Bye", function(e) {
		    elbl.innerHTML = "Bye from "+e.data;
		    console.log('Bye from ' + e.data);
		}, false);

		esource.addEventListener("version", function(e) {
		    elbl.innerHTML = "version event";
		    console.log('version event ongoing');
		    if (!DATA.STORES.VERS.check( JSON.parse(e.data) ))
			caja.xget('adjust', Object.assign({}, localStorage, sessionStorage)); // adjust version; sends fruit, week, vers
		}, false);

		// XXX not implemented YET
		esource.addEventListener("update", function(e) {
		    elbl.innerHTML = "update event";
		    console.log('update event ongoing');
		    const data = JSON.parse(e.data);
		    if (Array.isArray(data))
			Promise.all( data.map( updateOne ) );
		    else
			updateOne( data );
		}, false);

		esource.addEventListener("adjust", function(e) {
		    elbl.innerHTML = "adjust event";
		    console.log('adjust event ongoing');
		    if (e.data.match('json'))
			XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		    else
			Promise.all( JSON.parse(e.data).map( updateOne ) );
		}, false);

/*
		esource.addEventListener("query", function(e) {
		    elbl.innerHTML = "query event";
		    console.log('query event ongoing');
		    BROWSE.doSearch(e.data);
		}, false);
*/
		esource.addEventListener("uid", function(e) {
		    elbl.innerHTML = "uid event";
		    console.log("uid event received");
		    const data = e.data;
		    if (data.includes('json'))
			XHR.getJSON('json/' + data).then( a => a.forEach( add2bag ) );
		    else
			add2bag(JSON.parse( data));
		}, false);

		esource.addEventListener("feed", function(e) {
		    elbl.innerHTML = "feed event";
		    console.log("feed event received");
		    const data = e.data;
		    if (data.includes('json')) {
			caja.reset();
			XHR.getJSON('json/' + data).then( a => a.forEach( add2caja ) );
		    }
		    else
			add2caja(JSON.parse( data ));
		}, false);

		esource.addEventListener("ledger", function(e) {
		    elbl.innerHTML = "ledger event";
		    console.log("ledger event received");
		    const data = e.data;
		    caja.refresh();
		    if (data.includes('json')) {
			caja.reset();
			XHR.getJSON('json/' + data).then( a => a.forEach( add2fecha ) );
		    }
		    else
			add2fecha(JSON.parse( data ));
		}, false);

	})();

