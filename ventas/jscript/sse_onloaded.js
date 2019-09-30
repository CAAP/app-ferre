	// SSE - ServerSentEvent's
	(function ssevent() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById("frutas");
	    const pins = ferre.PINS;
	    const STORES = DATA.STORES;
	    const spin = document.getElementById('pacman');

		function ready() { spin.style.visibility = 'hidden'; }

		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }

		function distill( s ) {
		    let chunks = s.split('&query=');
		    const pid = Number( chunks.shift().match(/\d+/) );
		    return chunks.map(s => a2obj(s.split('|')));
		}

		function updateOne( o ) {
		    const store = o.store; delete o.store;
		    return STORES[store].update(o);
		}

		esource.onerror = () => { spin.style.visibility = 'visible' };

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    if (e.data.match(/[a-z]+/)) {
			console.log('I am ' + e.data);
			sessionStorage.fruit = e.data;
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
			ferre.xget('adjust', Object.assign({}, localStorage, sessionStorage)); // adjust version; sends fruit, week, vers
		}, false);

		esource.addEventListener("pins", function(e) {
		    elbl.innerHTML = "pins event";
		    console.log("pins event received");
		    const a = e.data.match(/pid=(\d+)&pincode=(\d+)/);
		    pins.set(Number(a[1]), Number(a[2]));
		}, false);

		esource.addEventListener("tabs", function(e) {
		    elbl.innerHTML = "tabs event";
		    console.log("tabs event received");
		    ferre.recreate( distill( e.data ) );
		}, false);

		esource.addEventListener("msgs", function(e) {
		    elbl.innerHTML = "msgs event";
		    console.log("msgs event received");
		    ferre.message( e.data );
		}, false);



/*
		esource.addEventListener("msgs", function(e) {
		    elbl.innerHTML = "msgs event";
		    console.log("msgs event received");
		    const d = e.data;
		    const pid = Number( d.match(/\d+/) );
		    const uid = d.match(/^=+/);
		    msgs.set(pid, uid);
		    console.log(e.data);
		}, false);

		esource.addEventListener("login", function(e) {
		    elbl.innerHTML = "login event";
		    console.log("login event received");
		    const a = e.data.match(/pid=(\d+)/);

		}, false);
*/

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

