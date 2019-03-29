	// SSE - ServerSentEvent's
	(function() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const STORES = DATA.STORES;

	    const add2caja = caja.add2caja;
	    const add2bag  = caja.add2bag;

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    console.log('I am ' + e.data);
		    localStorage.fruit = e.data;
		    flbl.innerHTML = e.data;
		    XHR.get( ferre.origin + 'CACHE?' + e.data );
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
			ferre.xget('adjust', localStorage); // adjust version; sends fruit, week, vers
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
		    XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		}, false);

		// XXX not in use YET
		esource.addEventListener("uid", function(e) {
		    elbl.innerHTML = "uid event";
		    console.log("uid event received");
		    XHR.getJSON('json/' + e.data).then( a => a.forEach( add2bag ));
		}, false);

		// XXX not in use YET
		esource.addEventListener("feed", function(e) {
		    elbl.innerHTML = "feed event";
		    console.log("feed event received");
		    const data = e.data;
		    if (data.includes('.json'))
			XHR.getJSON('json/' + data).then(a => a.forEach( add2caja ));
		    else
			add2caja(JSON.parse( data ));
		}, false);

	})();

