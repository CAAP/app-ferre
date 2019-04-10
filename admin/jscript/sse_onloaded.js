	// SSE - ServerSentEvent's
	(function() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const STORES = DATA.STORES;

	    const add2bag  = admin.add2bag;

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    console.log('I am ' + e.data);
		    localStorage.fruit = e.data;
		    flbl.innerHTML = e.data;
		    XHR.get( admin.origin + 'CACHE?' + e.data );
		    XHR.get( admin.origin + 'feed?' + e.data );
		    XHR.get( admin.origin + 'header?' + e.data );
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
			admin.xget('adjust', localStorage); // adjust (version) sends: fruit, week, vers
		}, false);

		esource.addEventListener("update", function(e) {
		    elbl.innerHTML = "update event";
		    console.log('update event ongoing');
		    XHR.get( admin.origin + 'version' ); //  notify ALL peers
		}, false);

		esource.addEventListener("adjust", function(e) {
		    elbl.innerHTML = "adjust event";
		    console.log('adjust event ongoing');
		    XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		}, false);

		esource.addEventListener("header", function(e) {
		    elbl.innerHTML = "header event";
		    console.log('header event ongoing');
		    JSON.parse(e.data).forEach( admin.addField );
		}, false);

		esource.addEventListener("query", function(e) {
		    elbl.innerHTML = "query event";
		    console.log('query event ongoing');
		    admin.setRecord( JSON.parse(e.data) );
		}, false);

	})();

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
