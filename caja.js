
        "use strict";

	var caja = {
	    DATA: { VERSION: 1, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    PEOPLE: {}
	};

	window.onload = function addFuns() {
	    const DATA = caja.DATA;
	    const DBs = [ DATA, TICKET ];

	    // SQL

	    SQL.DB = 'caja';

	    // FACTURAR

	    (function (){
		let diag = document.getElementById( 'dialogo-rfc' );
		let tabla = document.getElementById( 'tabla-rfc' );
		let ancho = new Set(['ciudad', 'correo', 'calle']);

		function makeDisplay( k ) {
		    let row = tabla.insertRow();
		    row.insertCell().appendChild( document.createTextNode(k.replace(/([A-Z])/g,' $1')) );
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 12; ie.name = k; ie.disabled = true;
		    if (ancho.has(k)) { ie.size = 25; }
		    if (k == 'razonSocial') { ie.size = 40; }
		    row.insertCell().appendChild( ie );
		}

		function fillVal( k, v ) {
		    let ie = tabla.querySelector('input[name='+k+']');
		    if (ie) { ie.value = v; }
		}

		XHR.getJSON('/ferre/factura.lua').then( a => a.forEach( makeDisplay ) );

		caja.timbrar = function() {
		    let rfc = TICKET.bagRFC;
		    XHR.getJSON('/ferre/rfc.lua?rfc=' + rfc)
			.then( a => {
			    if (a.length==1) {
				let q = a[0];
				for (let k in q) { fillVal(k, q[k]); }
				diag.showModal();
			    }
			});
		};

	    })();

	    // TICKET

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );
	    TICKET.timbre = TICKET.myticket.querySelector('button[name="timbrar"]');
	    TICKET.bagRFC = false;

	    (function() {
		const BRUTO = 1.16;
		const IVA = 7.25;
		const tiva = document.getElementById( TICKET.tivaID );
		const tbruto = document.getElementById( TICKET.tbrutoID );
		const ttotal = document.getElementById( TICKET.ttotalID );

		function tocents(x) { return (x / 100).toFixed(2); };

		TICKET.total = function(amount) {
		    tiva.textContent = tocents( amount / IVA );
		    tbruto.textContent = tocents( amount / BRUTO );
		    ttotal.textContent = tocents( amount );
		};

		const paga = document.getElementById( "dialogo-pagar" );
		const mytotal = paga.querySelector('input[name="cuenta"]');
		const mydebt =  paga.querySelector('output');

		caja.validar = function(e) {
		    if ( parseFloat(mydebt.value) >= 0 )
			paga.close();
		};

		caja.pagar = function() {
		    mytotal.value = ttotal.textContent;
		    paga.showModal();
		};

	    })();

	    caja.updateItem = TICKET.update;

	    caja.clickItem = e => TICKET.remove( e.target.parentElement );

	    caja.emptyBag = () => { TICKET.empty(); TICKET.bagRFC = false; TICKET.timbre.disabled = true; caja.cleanCaja(); }

	    caja.print = function(a) {
//		tag = a;
		document.getElementById('dialogo-persona').showModal();
	    };

	    // PEOPLE
	    (function() {
		PEOPLE.id = [];
		XHR.getJSON( '/ferre/empleados.lua' ).then( a => {
		    N = a.length;
		    a.forEach( o => { PEOPLE.id[o.id] = o.nombre; } );
		});
	    })();
	
	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt); };

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }
	    
	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	// ping CAJA
	    (function() {

		const cajita = document.getElementById('tabla-caja');
		const mybag = TICKET.bag;

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		function data( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.add ).then( () => { mybag.lastChild.dataset.uid = o.uid } ) }

		function add2bag( uid, rfc ) {
//			console.log("RFC: " + rfc + "\t" + (rfc == "undefined"));
		    if (!TICKET.bagRFC && (rfc != "undefined") && (rfc.length > 0) ) { TICKET.bagRFC = rfc; TICKET.timbre.disabled = false; }
		    SQL.get( { uid: uid } )
			.then( JSON.parse )
			.then( objs => objs.reduce( (seq, o) => seq.then( () => data(o) ), Promise.resolve() ) );
		}

//query selector look for property 'uid'
		let removeItem = uid => Array.from(mybag.querySelectorAll('tr[data-uid="' + uid + '"]')).reduce( (seq, tr) => seq.then( () => TICKET.remove(tr) ), Promise.resolve() );

		function add2caja(w) {
		    let row = cajita.insertRow(0);

		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid; ie.name = w.rfc;
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value, e.target.name); else removeItem(e.target.value); } );
		    row.insertCell().appendChild(ie);

		    w.nombre = PEOPLE.id[asnum(w.uid.substring(20))] || 'NaN';
		    w.time = w.uid.substr(11, 8);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    for (let k of ['time', 'nombre', 'count', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}

	// SERVER-SIDE EVENT SOURCE
		(function() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.onmessage = e => console.log( 'id: ' + e.lastEventId );
		    esource.addEventListener("feed", function(e) {
			console.log('FEED message received\n');
			JSON.parse( e.data ).forEach( add2caja );
		    }, false);
		})();

		caja.cleanCaja = function() {
		    Array.from(cajita.querySelectorAll("input:checked")).reduce( (_, ic) => { ic.checked = false; }, {} );
		};

	    })();

	};
