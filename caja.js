        "use strict";

	var caja = {};

	window.onload = function addFuns() {
	    const DBs = [ DATA ];

	    caja.cerrar = e => e.target.closest('dialog').close();

	    // SQL

	    SQL.DB = 'caja';

	    // PEOPLE - Scheduling support

	    (function() {
		const slc = document.getElementById('personas');
		const tag = document.getElementById('tag');
		const schedule = document.getElementById('dialogo-schedule');
		const action = schedule.querySelector('button[name=action]');

		let msg_tag = pid => {
			tag.textContent = PEOPLE.horarios.get(pid);
			if ((tag.textContent[0] == 'E') ^ (tag.classList.contains('entrada')))
			    tag.classList.toggle('entrada');
		}

		caja.marcar = e => {
		    const a = e.target.textContent;
		    XHR.get( document.location.origin + ':8081/marcar?id_tag=h&tag=' + a + '&pid=' + slc.value )
			.then( () => schedule.close() );
		};

		caja.showD = () => {
		    action.textContent = (tag.textContent[0] == 'E') ? 'SALIDA' : 'ENTRADA';
		    schedule.showModal();
		};

		caja.tab = () => {
		    const pid = Number(slc.value);
		    if (pid == 1) { tag.textContent = ''; return; }
		    if (PEOPLE.horarios.has(pid)) { msg_tag( pid ); }
		    else { tag.textContent = ''; action.textContent = 'ENTRADA'; schedule.showModal(); }
		};

// maybe after loading add SSE streaming for 'feed' events
		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); slc.appendChild(opt); } ) );

		PEOPLE.horarios = new Map();

	    })();


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

	    // PAGAR

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

//		PAGADO can be added to ticket, it's a map
		caja.pagar = function() {
		    mytotal.value = ttotal.textContent;
		    paga.showModal();
		};

	    })();

	    // TICKET

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );
	    TICKET.timbre = TICKET.myticket.querySelector('button[name="timbrar"]');
	    TICKET.bagRFC = false;

	    caja.updateItem = TICKET.update;

	    caja.clickItem = e => TICKET.remove( e.target.parentElement );

	    caja.emptyBag = () => { TICKET.empty(); TICKET.bagRFC = false; TICKET.timbre.disabled = true; caja.cleanCaja(); }

	    caja.print = function(a) {
		const tag = a || 'ticket';
//		const week = document.getElementById('tabla-caja').dataset.week; // XXX cajita?
		const total = document.getElementById( TICKET.ttotalID ).textContent;
		let objs = ['tag='+tag, 'total='+total];
		TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );
//		return XHR.get(document.location.origin+':5555/print?'+objs.join('&'));
		return SQL.print( objs ).then( caja.emptyBag );
	    };


	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // HEADER

	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    	const now = new Date().toLocaleDateString('es-MX', FORMAT);

		note.appendChild( document.createTextNode( now ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	// ping CAJA
	    (function() {
		const cajita = document.getElementById('tabla-caja');
		const mybag = TICKET.bag;

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		function data( o ) { return IDB.readDB( DATA ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.show ).then( () => { mybag.lastChild.dataset.uid = o.uid } ) }

		function add2bag( uid, rfc ) {
		    if (!TICKET.bagRFC && (rfc != "undefined") && (rfc.length > 0) ) { TICKET.bagRFC = rfc; TICKET.timbre.disabled = false; }
		    SQL.get( { uid: uid, week: cajita.dataset.week } )
			.then( JSON.parse )
			.then( objs => objs.reduce( (seq, o) => seq.then( () => data(o) ), Promise.resolve() ) );
		}

//query selector look for property 'uid'
		let removeItem = uid => Array.from(mybag.querySelectorAll('tr[data-uid="' + uid + '"]')).reduce( (seq, tr) => seq.then( () => TICKET.remove(tr) ), Promise.resolve() );

		function add2caja(w) {
		    let row = cajita.insertRow(0);

		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid; ie.name = '';// w.rfc;
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value, e.target.name); else removeItem(e.target.value); } );
		    row.insertCell().appendChild(ie);

		    w.nombre = PEOPLE.id[asnum(w.uid.substr(-1))] || 'NaP';
		    w.time = w.uid.substr(11,5);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    w.total = (w.totalCents / 100).toFixed(2);
		    for (let k of ['time', 'nombre', 'count', 'total', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}

	// SERVER-SIDE EVENT SOURCE
		(function() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.addEventListener("feed", function(e) {
			console.log('FEED message received\n');
			JSON.parse( e.data ).forEach( add2caja );
		    }, false);
		    esource.addEventListener("week", function(e) {
			let week = JSON.parse( e.data );
			cajita.dataset.week = week;
			console.log('WEEK: ' + week);
		    }, false);
		    esource.addEventListener("entradas", function(e) {
			JSON.parse( e.data ).forEach( p => PEOPLE.horarios.set( p.pid, p.tag + ' ' + p.hora ) );
			caja.tab();
		    }, false);
		})();

		caja.cleanCaja = function() {
		    Array.from(cajita.querySelectorAll("input:checked")).reduce( (_, ic) => { ic.checked = false; }, {} );
		};

	    })();

	};
