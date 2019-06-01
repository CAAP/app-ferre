	// SSE - ServerSentEvent's
	(function ssevent() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const tabs = ferre.TABS;
	    const STORES = DATA.STORES;

		function ready() { document.getElementById('pacman').style.visibility = 'hidden'; }

		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }

		function distill( s ) {
		    let chunks = s.split('&query=');
		    const pid = Number( chunks.shift().match(/\d+/) );
		    tabs.set(pid, chunks.map(s => a2obj(s.split('|'))));
		}

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    if (e.data.match(/[a-z]+/)) {
			console.log('I am ' + e.data);
			localStorage.fruit = e.data;
			flbl.innerHTML = e.data;
			ready();
			XHR.get( ferre.origin + 'CACHE?' + e.data )
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
		console.log(e.data);
		    if (!DATA.STORES.VERS.check( JSON.parse(e.data) ))
			ferre.xget('adjust', localStorage); // adjust version; sends fruit, week, vers
		}, false);

		esource.addEventListener("delete", function(e) {
		    const pid = Number( e.data.match(/\d+/) );
		    tabs.delete( pid );
		    console.log('Removing ticket'); // PEOPLE.id[pid]
		    elbl.innerHTML = "delete event";
		}, false);

		esource.addEventListener("tabs", function(e) {
		    elbl.innerHTML = "tabs event";
		    console.log("tabs event received");
		    distill( e.data );
		}, false);

		esource.addEventListener("adjust", function(e) {
		    elbl.innerHTML = "adjust event";
		    console.log('adjust event ongoing');
		    XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		}, false);

		esource.addEventListener("query", function(e) {
		    elbl.innerHTML = "query event";
		    console.log('query event ongoing');
		    BROWSE.doSearch(e.data);
		}, false);

	})();

