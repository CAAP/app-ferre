	// WSE - WebSocket's Events
	(function wsevent() {
	    let wsc = new WebSocket(document.location.origin.replace('http', 'ws')+':5030');

	    function reloadme() {
		wsevent();
	    }

	    function retry() {
		console.log("Socket was closed. Reconnect will be attempted in 5 secs");
		WSE.timerID = setTimeout(reloadme, 5000);
	    }

	    wsc.onclose = () => { spin.style.visibility = 'visible'; retry(); };

	    wsc.onopen = () => {
		spin.style.visibility = 'hidden';
		if (WSE.timerID != -1) {
		    clearTimeout(WSE.timerID);
		    WSE.timerID = -1;
		}
	    };

	    const elbl = document.getElementById("eventos");
	    const flbl = document.getElementById("frutas");
	    const spin = document.getElementById('pacman');
	    const persona = document.getElementById('personas');

	    const STORES = DATA.STORES;

	    function updateOne( o ) {
		const store = o.store; delete o.store;
		return STORES[store].update(o);
	    }

	    wsc.onmessage = ev => { let a = JSON.parse(ev.data); WSE[a.cmd](a); };

	    let wsend = o => wsc.send(JSON.stringify(o));

	    WSE.send = wsend;

	    WSE.wsc = wsc;

	    // First message received after successful handshake
	    WSE.fruit = o => {
		let fruit = o.fruit;
		console.log('I am ' + fruit);
		sessionStorage.fruit = fruit;
		flbl.innerHTML = fruit;
		if (typeof caja != "undefined")
		    wsend({cmd: 'feed', fruit: fruit});
		if (typeof ferre != "undefined")
		    WSE.send({cmd: 'people', fruit: sessionStorage.fruit});
	    };

	    WSE.people = o => {
		elbl.innerHTML = "people event";
		console.log('employees event ongoing');
		if (typeof ferre != "undefined")
		    ferre.employees(o.data);
	    };

	    WSE.version = o => {
		elbl.innerHTML = "version event";
		console.log('version event ongoing');
		if (DATA.STORES.VERS.check( o )) {
		    let start = new Date(localStorage.version);
		    let end = new Date(o.version);
		    let elapsed = (end-start)/(3600*24*1000.0);
		    if ((typeof localStorage.version != "undefined") && elapsed > 5)
			return IDB.recreateDB( DATA.STORES.PRICE );
		    else
			wsend(Object.assign({cmd: 'adjust'}, localStorage, sessionStorage));
		} else
		    DATA.STORES.VERS.inplace( o );
	    };

	    WSE.adjust = o => {
		elbl.innerHTML = "adjust event";
		console.log('adjust event ongoing');
		let data = JSON.parse(o.msg);
		Promise.all(data.map(updateOne));
	    };

	    WSE.pins = o => {
		console.log("pins event received");
		if (typeof ferre != "undefined")
		    ferre.PINS.set(Number(o.pid), Number(o.pincode));
	    };

	    WSE.tabs = o => {
		console.log("uid event received");
		if (typeof ferre != "undefined")
		    ferre.fetchMe( o );
		else if (typeof caja != "undefined")
		    caja.add2bag( o );
	    };

	    WSE.uid = WSE.tabs; // XXX fetchMe

	    WSE.msgs = o => {
		elbl.innerHTML = "msgs event";
		console.log("msgs event received");
		if (typeof ferre != "undefined")
		    ferre.message( o );
	    };

	    WSE.logout = o => {
		let pid = o.pid;
		elbl.innerHTML = "logout event";
		console.log("logout event received");
		if ((typeof ferre != "undefined") && (Number(pid) == Number(persona.value))) {
		    TICKET.empty(); ferre.logout();
		    return true;
		}
	    };

	    WSE.query = o => {
		elbl.innerHTML = "query event";
		console.log('query event ongoing');

		if ((typeof(admin) != "undefined") && o.hasOwnProperty("desc")) {
		    if (o.desc.match('VV'))
			admin.setRecord( {clave: o.clave} );
		    else
			admin.setRecord( o );
		} else
		    BROWSE.doSearch(o.clave);

	    };

	    WSE.feed = o => {
		elbl.innerHTML = "feed event";
		console.log("feed event received");
		if (typeof(caja) != "undefined")
		    caja.add2caja( o );
	    };

	    WSE.ledger = o => {
		elbl.innerHTML = "ledger event";
		console.log("ledger event received");
		if (typeof(caja) != "undefined")
		    caja.add2fecha( o );
	    };

	})();

/*

		esource.addEventListener("miss", function(e) {
		    elbl.innerHTML = "miss event";
		    console.log("miss event received");
		    ferre.MISS = true;
		    TICKET.empty();
		}, false);

		esource.addEventListener("adjust", function(e) {
		    elbl.innerHTML = "adjust event";
		    console.log('adjust event ongoing');
		    if (e.data.match('json'))
			XHR.getJSON( '/ventas/json/' + e.data ).then( data => Promise.all( data.map( updateOne ) ) );
		    else
			Promise.all( JSON.parse(e.data).map( updateOne ) );
		}, false);
*/

