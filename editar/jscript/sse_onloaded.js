	// SSE - ServerSentEvent's
	(function ssevent() {
	    let esource = new EventSource(document.location.origin+':5030');

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById("frutas");
	    const spin = document.getElementById('pacman');

		function ready() { spin.style.visibility = 'hidden'; }

		esource.onerror = () => { spin.style.visibility = 'visible' };

		// First message received after successful handshake
		esource.addEventListener("fruit", function(e) {
		    if (e.data.match(/[a-z]+/)) {
			console.log('I am ' + e.data);
			sessionStorage.fruit = e.data;
			flbl.innerHTML = e.data;
			ready();
			XHR.get( editar.origin + 'CACHE?' + e.data )
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

		esource.addEventListener("pins", function(e) {
		    elbl.innerHTML = "pins event";
		    console.log("pins event received");
		    const a = e.data.match(/pid=(\d+)&pincode=(\d+)/);
		    pins.set(Number(a[1]), Number(a[2]));
		}, false);

	})();

