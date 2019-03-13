	// SSE - ServerSentEvent's
	(function() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById('frutas');
	    const tabs = ferre.TABS;
	    const STORES = DATA.STORES;

		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }

		function distill( s ) {
		    let chunks = s.split('&query=');
		    const pid = Number( chunks.shift().match(/\d+/) );
		    tabs.set(pid, chunks.map(s => a2obj(s.split('+'))));
		}

		esource.addEventListener("Hi", function(e) {
		    elbl.innerHTML = "Hi from "+e.data;
		    console.log('Hi from ' + e.data);
		}, false);

		esource.addEventListener("Bye", function(e) {
		    elbl.innerHTML = "Bye from "+e.data;
		    console.log('Bye from ' + e.data);
		}, false);

		esource.addEventListener("fruit", function(e) {
		    console.log('I am ' + e.data);
		    localStorage.fruit = e.data;
		    flbl.innerHTML = e.data;
		    XHR.get( ferre.origin + 'CACHE?' + e.data );
		}, false);

		esource.addEventListener("version", function(e) {
		    elbl.innerHTML = "version event";
		    console.log('version event ongoing');
		    if (!DATA.STORES.VERS.check( JSON.parse(e.data) ))
			ferre.xget('adjust', localStorage); // adjust version-time
		}, false);

		esource.addEventListener("delete", function(e) {
		    const pid = Number( e.data );
		    tabs.delete( pid );
		    console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    elbl.innerHTML = "delete event";
		}, false);

		esource.addEventListener("tabs", function(e) {
		    elbl.innerHTML = "tabs event";
		    console.log("tabs event received");
		    distill( e.data );
		}, false);

		esource.addEventListener("update", function(e) {
		    elbl.innerHTML = "update event";
		    console.log('update event ongoing');
		    const o = JSON.parse(e.data);
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}, false);

	})();

