        "use strict";

	var ferre = {
	    DATA:  { VERSION: 1, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' }
	};

	window.onload = function() {
	    const DATA = ferre.DATA;
	    const DBs = [ DATA ]; // , TICKET

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    ferre.startSearch = BROWSE.startSearch;

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.scroll = BROWSE.scroll;

	    ferre.cerrar = e => e.target.closest('dialog').close();

	    // FACTURAR

	    (function() {
		let diagR = document.getElementById( 'dialogo-rfc' );
		let diagF = document.getElementById( 'dialogo-factura' );
		let tabla = document.getElementById( 'tabla-rfc' );

		function makeDisplay( k ) {
		    let row = tabla.insertRow();
		    row.insertCell().appendChild( document.createTextNode(k.replace(/([A-Z])/g,' $1')) );
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 12; ie.name = k;
		    if (k == 'cp') { ie.type = 'search'; ie.placeholder = '00000'; ie.pattern = '\d+'; }
		    if (k == 'razonSocial') { ie.size = 40; }
		    if (k == 'rfc') { ie.type = 'search'; ie.placeholder = 'XAXX010101000'; ie.pattern = '^\w{3,4}\d{6}\w{3}$'; }
		    row.insertCell().appendChild( ie );
		}

		function fillVal( k, v ) {
		    let ie = tabla.querySelector('input[name='+k+']');
		    if (ie) { ie.value = v; }
		}

		function clearVals() { Array.from(tabla.querySelectorAll('input')).forEach( item => { item.value = ''; } ); }

		function displayRFC(e) {
		    let rfc = e.target;
		    if ((rfc.value.length>10) && (rfc.validity.valid))
			    XHR.getJSON('/ferre/rfc.lua?rfc=' + rfc.value)
			    .then( a => {
				if (a.length==1) {
				    let q = a[0];
				    for (let k in q) { fillVal(k, q[k]); }
				    ferre.factura();
				}
			    });
		}

		function correos() {
		    XHR.get('http://www.correosdemexico.gob.mx/lservicios/servicios/descarga.aspx')
			.then( data => console.log(data) );
		}

		// FIll-in the fields of 'tabla-rfc' inside 'dialogo-rfc'
		XHR.getJSON('/ferre/factura.lua')
		    .then( a => a.forEach( makeDisplay ) )
		    .then( () => {
//			['colonia', 'ciudad', 'estado'].forEach( x => { tabla.querySelector('input[name="'+x+'"').disabled = true; } );
			['ciudad', 'correo', 'calle'].forEach( x => { tabla.querySelector('input[name="'+x+'"').size = 25; } );
//			tabla.querySelector('input[name="cp"]').addEventListener('change', correos, false);
		    });

		diagR.querySelector('input[type=search]').addEventListener("keyup", displayRFC, false);

		ferre.rfc = () => diagR.showModal();

		ferre.factura = () => { diagR.close(); diagR.querySelector('input').value = ''; diagF.showModal(); };

		ferre.enviarF = () => { diagF.close(); ferre.print('facturar', tabla.querySelector('input[name=rfc]').value); clearVals(); };

	    })();

	    // TICKET

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    (function() {
		let diagI = document.getElementById('dialogo-item');
		let clave = -1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

		ferre.asnum = e => { e.target.value = Number(e.target.textContent) };

		ferre.menu = e => { clave = asnum(e.target.parentElement.dataset.clave); diagI.showModal(); };

		// Add: faltante XXX
		ferre.add2bag = function() {
		    diagI.close();
		    if (TICKET.items.has( clave )) { console.log('Item is already in the bag.'); return false; } // MAYBE not needed by diagI XXX
		    return IDB.readDB( DATA ).get( clave )
			.then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } ) // MAYBE simplified by diagI XXX
			.then( TICKET.add );
		};
	    })();

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

	    ferre.emptyBag = TICKET.empty;

	    ferre.print = function(a, arg1) {
		const id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		let rfc = ''; if (a == 'facturar') { rfc = arg1; };
		const pid = document.getElementById('personas').dataset.id;
		let objs = ['id_tag='+id_tag, 'id_person='+pid, 'rfc='+rfc, 'count='+TICKET.items.size ];

		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );

		return SQL.print( objs ).then( ferre.emptyBag );
	    };

	    (function() {
		const ttotal = document.getElementById( TICKET.ttotalID );
		TICKET.total = function(amount) { ttotal.textContent = (amount / 100).toFixed(2); };
	    })();

	    // SQL

	    SQL.DB = document.location.origin + ':8081';

	    // PEOPLE - Multi-User support

	    (function() {
		const slc = document.getElementById('personas');
		slc.dataset.id = 1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
		function data( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ); }
		function a2obj( a ) { const M = a.length/2; let o = {}; for (let i=0; i<M; i++) { o[a[i*2]] = a[i*2+1]; } return o; }
		function recreate(q) { return q.split('&args=').reduce( (p, s) => p.then( () => data(a2obj(s.split('+'))) ), Promise.resolve() ); }
		function tabs(k) { slc.dataset.id = k; if (PEOPLE.tabs.has(k)) { recreate(PEOPLE.tabs.get(k).query); } }

		ferre.tab = e => {
		    const pid = Number(e.target.value);
	// if ticket-bag is not empty then send info to server for broadcasting
		    if (TICKET.items.size > 0) { ferre.print('guardar').then( () => tabs(pid) ); }
		    else { tabs(pid); }
		};

		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); slc.appendChild(opt); } ) );

	    })();

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // HEADER
	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	// SERVER-SIDE EVENT SOURCE
		(function() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.onmessage = e => console.log( 'id: ' + e.lastEventId );
		    esource.addEventListener("save", function(e) {
			const o = JSON.parse( e.data )[0];
			o.query = o.query.substr(o.query.search('args') + 5);
			PEOPLE.tabs.set(Number(o.id_person), o);
			console.log('Message for: ' + PEOPLE.id[o.id_person]);
		    }, false);
		    esource.addEventListener("delete", function(e) {
			const pid = Number(e.data);
			PEOPLE.tabs.delete(pid);
			console.log('Remove ticket for: ' + PEOPLE.id[pid]);
		    }, false);
		})();

	};

