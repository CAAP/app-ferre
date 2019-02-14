

	    (function() {

		function a2obj( a ) {
		    const M = a.length/2;
		    let o = {};
		    for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; }
		    return o;
		}

	    let updateMe = data => Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) ); // XXX Needed???

		function recreateDB() {
		    let esource = new EventSource(document.location.origin + ":5030");
		    esource.addEventListener("upgrade", function(e) {
			JSON.parse( e.data ).
		    }, false);
		}

		let esource = new EventSource(document.location.origin + ":5030");

//		    DATA.onLoaded(esource);	XXX
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


