        "use strict";

	var caja = {};

	window.onload = function addFuns() {

	    const PRICE = DATA.STORES.PRICE;

	    caja.cerrar = e => e.target.closest('dialog').close();

	    caja.print = () => Promise.all(Array.from(TICKET.bagUID).map( encodeURIComponent ).map( k => XHR.get('/caja/print.lua?uid='+k) )); // XXX should be POST;

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
		const money = paga.querySelector('input[name="recibo"]');
		const mydebt =  paga.querySelector('output');

		let procesar = {};

		function validar() {
		    if ( parseFloat(mydebt.value) >= 0 )
			paga.close();
		}

		procesar.credito = function() {
//		    let rfc = e.target.closest('input[name="rfc"]').value;
		}

		procesar.efectivo = function() {
		}

//		PAGADO can be added to ticket, it's a map
		caja.pagar = function() {
		    let total = ttotal.textContent;
		    mytotal.value = total;
		    money.value = total;
		    paga.showModal();
		    money.select();
		};

		caja.acreditar = function(e) {
		    procesar[e.name]();
		    validar();
		};

	    // FACTURAR

		const hoy = new Date().toLocaleDateString('es-MX');

		let rmamp = s => s.replace('&', '');

		function fillme(o, letra) {
		    let prc = o.precios[o.precio].split(' / ');
		    let p = (100 * prc[0] * (100-o.rea) / 1e4).toFixed(2);
		    let u = (prc[1].length > 0) ? prc[1] : 'PZ';
		    let ret = ['"XXXX"', hoy, '"XXXX"', '"."', '"."', '"."', o.qty, '"'+rmamp(o.desc)+'"', '"'+u+'"', p, (o.totalCents/100).toFixed(2), '"SUBTOTAL"', tbruto.textContent,'"IVA"', tiva.textContent, '"TOTAL"', ttotal.textContent, '"'+letra.replace('\n','')+'"'];
		    return ret.join('\t');
		}

		function temporal(s) {
		    let ret = [];
		    TICKET.items.forEach(item => ret.push( fillme(item, s) ));
		    let b = new Blob([ret.join('\n')], {type: 'text/html'});
		    let a = document.createElement('a');
		    let url = URL.createObjectURL(b);
		    a.href = url;
		    a.download = 'facturar.tsv'
		    a.click();
		    URL.revokeObjectURL(url);
		}

		caja.timbrar = () => XHR.get('/caja/pesos.lua?pesos='+ttotal.textContent).then( temporal )
	    })();

	    // TICKET

	    TICKET.load_tags();

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );
	    TICKET.timbre = TICKET.myticket.querySelector('button[name="timbrar"]');
	    TICKET.bagRFC = false;
	    TICKET.bagUID = new Set(); // XXX Ordered Set instead?

	    TICKET.extraEmpty = () => true;

	    TICKET.redondeo = x => x; // TEMPORAL x FACTURAR

	    caja.updateItem = TICKET.update;

	    caja.clickItem = e => TICKET.remove( e.target.parentElement );
// TICKET.timbre.disabled = true; 
	    caja.emptyBag = () => { TICKET.empty(); TICKET.bagUID.clear(); TICKET.bagRFC = false; caja.cleanCaja(); }

		// XXX Temporal
/*
	    caja.print2 = function() {
		if (TICKET.items.size > 0) {
		let objs = ['uid='+1, 'tag=CAJA'];
		    TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );
		}
	    };
*/

	    // HEADER

	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    	const now = new Date().toLocaleDateString('es-MX', FORMAT);

		note.appendChild( document.createTextNode( now ) );
	    })();

	    // FOOTER

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	// ping CAJA

	    (function() {
		const cajita = document.getElementById('tabla-caja');
		const cajaOld = document.getElementById('tabla-caja-old');
		const mybag = TICKET.bag;
		const clearTable = DATA.clearTable;

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		// XXX  lastChild dataset add UUID : uuid||id_tag||clave
		// XXX clave may not exists ??? XXX
		function data( o ) {
		    return IDB.readDB( PRICE )
			.get( asnum(o.clave) )
			.then( w => { if (w) { return Object.assign( o, w, {id: o.clave} ) } else { return Promise.reject() } } )
			.then( TICKET.show )
			.then( () => { mybag.lastChild.dataset.uid = o.uid } )
			.catch( e => console.log(e) )
		}

		function add2bag( uid, id_tag ) {  //  rfc
		    TICKET.bagUID.add( uid ); // XXX REMOVE
//XXX RFC!Here?		    if (!TICKET.bagRFC && (rfc != "undefined") && (rfc.length > 0) ) { TICKET.bagRFC = rfc; TICKET.timbre.disabled = false; }
		    XHR.getJSON('/caja/get.lua?uid='+uid) // XXX uuid : uid || id_tag
			.then( objs => Promise.all( objs.map( data ) ) );
		}

		caja.cleanCaja = () => Array.from(cajita.querySelectorAll("input:checked")).forEach(ic => {ic.checked = false });

		let removeByUID = uid => Promise.all( Array.from(mybag.querySelectorAll('tr[data-uid="' + uid + '"]')).map( TICKET.remove ) );

//		const doprint = document.getElementById("doprint");

		const regInt = /\d+$/;

		function addRow( row, w ) {
		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid; ie.name = w.id_tag;// ie.name = w.rfc || ((TICKET.TAGS.facturar == w.id_tag) && 'XXX');
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value, e.target.name); else removeByUID(e.target.value); } );
		    row.insertCell().appendChild(ie);

		    w.nombre = PEOPLE.id[w.uid.match(regInt)[0]] || 'NaP';
		    w.time = w.uid.substr(11,5);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    w.total = (w.totalCents / 100).toFixed(2);
		    for (let k of ['time', 'nombre', 'count', 'total', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}


		function add2caja(w) {
		    let row = cajita.insertRow(0);
		    addRow(row, w);
		}

		function add2cajaOld(w) {
		    let row = cajaOld.insertRow();
		    addRow(row, w);
		}

		// SearchByDate
		caja.getByDate = e => XHR.getJSON('/caja/getDate.lua?uid='+e.target.value).then(data => {clearTable(cajaOld); data.forEach(add2cajaOld)});

	// SERVER-SIDE EVENT SOURCE
		function addEvents() {	
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		    esource.addEventListener("feed", function(e) {
			console.log('FEED message received\n');
			JSON.parse( e.data ).forEach( add2caja );
		    }, false);
		}

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( PEOPLE.load ).then( addEvents );

	    })();

	};
