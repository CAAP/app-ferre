        "use strict";

	var ferre = {
	    DATA:  { VERSION: 1, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
//	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' }
	};

	window.onload = function() {
	    const DATA = ferre.DATA;
	    const DBs = [ DATA, TICKET ];

//	    ferre.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    ferre.startSearch = BROWSE.startSearch;

	    ferre.keyPressed = BROWSE.keyPressed;

	    ferre.scroll = BROWSE.scroll;

	    // FACTURAR

	    (function() {

		let diagR = document.getElementById( 'dialogo-rfc' );
		let diagF = document.getElementById( 'dialogo-factura' );
		let tabla = document.getElementById( 'tabla-rfc' );

		// Create a table with 2 cols, a field/label and a value/input-text
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

		function displayRFC() {
		    let rfc = diagR.querySelector('input');
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

		function sepomex(e) {
		    let cp = e.target.value;
		    if (e.target.validity.valid) {
		    }
		}

		// FIll-in the fields of 'tabla-rfc' inside 'dialogo-rfc'
		XHR.getJSON('/ferre/factura.lua')
		    .then( a => a.forEach( makeDisplay ) )
		    .then( () => {
//			['colonia', 'ciudad', 'estado'].forEach( x => { tabla.querySelector('input[name="'+x+'"').disabled = true; } );
			['ciudad', 'correo', 'calle'].forEach( x => { tabla.querySelector('input[name="'+x+'"').size = 25; } );
//			tabla.querySelector('input[name="cp"]').addEventListener('change', correos, false);
		    });

		diagR.querySelector('input').addEventListener("keyup", displayRFC, false);

		ferre.rfc = () => diagR.showModal();

		ferre.factura = () => { diagR.close(); diagR.querySelector('input').value = ''; diagF.showModal(); };

		ferre.enviarF = () => { diagF.close(); ferre.print('facturar', tabla.querySelector('input[name=rfc]').value); clearVals(); };

	    })();

	    // TICKET

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };
	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );

	    let id_tag = TICKET.TAGS.none;
	    let rfc = '';

	    ferre.add2bag = function( e ) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		return IDB.readDB( TICKET ).get( clave )
		    .then( q => { if (q) { return Promise.reject('Item is already in the bag.'); } else { return IDB.readDB( DATA ).get(clave); } } )
		    .then( w => { w.qty=1; w.precio='precio1'; w.rea=0; w.totalCents=uptoCents(w); return w; } )
		    .then( TICKET.add );
	    };

	    ferre.updateItem = TICKET.update;

	    ferre.clickItem = e => TICKET.remove( e.target.parentElement );

	    ferre.emptyBag = TICKET.empty;

	    ferre.print = function(a, arg1) {
		id_tag = TICKET.TAGS[a] || TICKET.TAGS.none;
		if (a == 'facturar') { rfc = arg1; } else { rfc = ''; };
		document.getElementById('dialogo-persona').showModal();
	    };

	    (function() {
		const ttotal = document.getElementById( TICKET.ttotalID );
		TICKET.total = function(amount) {
		    ttotal.textContent = (amount / 100).toFixed(2);
		};
	    })();

	    // SQL

	    SQL.DB = document.location.origin + ':8081';

	    // PEOPLE | SET Person Dialog | Send to CAJA
	    (function() {
		const dialog = document.getElementById('dialogo-persona');
		let ol = document.createElement('ol');
		let N = -1;
		dialog.appendChild(ol);

		let addOne = o => { ol.appendChild( document.createElement('li') ).textContent = o.nombre };

		function plain(obj) {
		    let ret = [];
		    for (let k in obj) { ret.push(k, obj[k]); }
		    return ('args=' + ret.join('+'));
		}

		function sending(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    if (k < 1 || k > N) { e.target.value = ''; return false; }
		    dialog.close();
		    e.target.value = '';
		    let objs = ['id_tag='+id_tag, 'id_person='+k, 'rfc='+rfc];
		    return IDB.readDB( TICKET ).count()
			.then( q => objs.push( 'count='+q ) )
			.then( () => IDB.readDB( TICKET ).openCursor( cursor => {
			    if (cursor) {
				let o = TICKET.obj(cursor.value);
				objs.push( plain(o) );
				cursor.continue();
			    } else { SQL.print( objs ).then( ferre.emptyBag ); } } ) );
		}

		XHR.getJSON( '/ferre/empleados.lua' ).then( a => {
		    N = a.length;
		    a.forEach( addOne );
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 1;
		    ie.addEventListener('keyup', sending);
		    dialog.appendChild( ie );
		});
	    })();

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // SET HEADER
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	};

