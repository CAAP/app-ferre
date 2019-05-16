	// SSE - ServerSentEvent's
	(function() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const STORES = DATA.STORES;

	    const addInvoice = facturas.addInvoice;
	    const add2bag  = facturas.add2bag;

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    console.log('I am ' + e.data);
		    localStorage.fruit = e.data;
		    flbl.innerHTML = e.data;
		    XHR.get( facturas.origin + 'CACHE?' + e.data );
//		    XHR.get( facturas.origin + 'facturas?' + e.data );
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
			facturas.xget('adjust', localStorage); // adjust version; sends fruit, week, vers
		}, false);

/*
		esource.addEventListener("update", function(e) {
		    elbl.innerHTML = "update event";
		    console.log('update event ongoing');
		    const data = JSON.parse(e.data);
		    if (Array.isArray(data))
			Promise.all( data.map( updateOne ) );
		    else
			updateOne( data );
		}, false);
*/

		esource.addEventListener("adjust", function(e) {
		    elbl.innerHTML = "adjust event";
		    console.log('adjust event ongoing');
		    XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		}, false);

		esource.addEventListener("uid", function(e) {
		    elbl.innerHTML = "uid event";
		    console.log("uid event received");
		    XHR.getJSON('/caja/json/' + e.data).then( a => a.forEach( add2bag ));
		}, false);

		esource.addEventListener("facturas", function(e) {
		    elbl.innerHTML = "facturas event";
		    console.log("facturas event received");
		    const data = e.data;
		    if (data.includes('json'))
			XHR.getJSON('json/' + data).then(a => a.forEach( addInvoice ));
		    else
			addInvoice(JSON.parse( data ));
		}, false);

	})();

