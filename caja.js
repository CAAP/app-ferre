        "use strict";

	var caja = {};

	window.onload = function addFuns() {

	    const PRICE = DATA.STORES.PRICE;

	    caja.cerrar = e => e.target.closest('dialog').close();

	    caja.print = () => Promise.all(Array.from(TICKET.bagUID).map( encodeURIComponent ).map( k => XHR.get('/ticket/print.lua?uid='+k) )); //SQL.print({week: cajita.dataset.week, uid: k })));

	    // SQL

	    SQL.DB = 'caja';
	
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
		    let rfc = e.target.closest('input[name="rfc"]').value;
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

		function fillme(o, letra) {
		    let prc = o.precios[o.precio].split(' / ');
		    let p = (100 * prc[0] * (100-o.rea) / 1e4).toFixed(2);
		    let u = (prc[1].length > 0) ? prc[1] : 'PZ';
		    let ret = ['"XXXX"', hoy, '"XXXX"', '"."', '"."', '"."', o.qty, '"'+o.desc+'"', '"'+u+'"', p, (o.totalCents/100).toFixed(2), '"SUBTOTAL"', tbruto.textContent,'"IVA"', tiva.textContent, '"TOTAL"', ttotal.textContent, '"'+letra.replace('\n','')+'"'];
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

	    TICKET.bag = document.getElementById( TICKET.bagID );
	    TICKET.myticket = document.getElementById( TICKET.myticketID );
	    TICKET.timbre = TICKET.myticket.querySelector('button[name="timbrar"]');
	    TICKET.bagRFC = false;
	    TICKET.bagUID = new Set(); // XXX Ordered Set instead?

	    TICKET.extraEmpty = () => true;

	    caja.updateItem = TICKET.update;

	    caja.clickItem = e => TICKET.remove( e.target.parentElement );

	    caja.emptyBag = () => { TICKET.empty(); TICKET.bagUID.clear(); TICKET.bagRFC = false; TICKET.timbre.disabled = true; caja.cleanCaja(); }

	    caja.print2 = function() {
		if (TICKET.items.size > 0) {
		let objs = ['uid='+, 'tag=CAJA'];
		    TICKET.items.forEach( item => objs.push( 'args=' + TICKET.plain(item) ) );
		}
	    };


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
		const mybag = TICKET.bag;

	 	function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		function data( o ) { return IDB.readDB( PRICE ).get( asnum(o.clave) ).then( w => Object.assign( o, w ) ).then( TICKET.show ).then( () => { mybag.lastChild.dataset.uid = o.uid } ) }

		function add2bag( uid, rfc ) {  //  rfc
		    TICKET.bagUID.add( uid );
		    if (!TICKET.bagRFC && (rfc != "undefined") && (rfc.length > 0) ) { TICKET.bagRFC = rfc; TICKET.timbre.disabled = false; }
		    SQL.get( { uid: uid } )
			.then( JSON.parse )
			.then( objs => Promise.all( objs.map( data ) ) );
		}

		caja.cleanCaja = () => Array.from(cajita.querySelectorAll("input:checked")).forEach(ic => {ic.checked = false });

		let removeItem = uid => Promise.all( Array.from(mybag.querySelectorAll('tr[data-uid="' + uid + '"]')).map( TICKET.remove ) );

// XXX check may be innecesary to look for pid & time since it comes from feed
		const doprint = document.getElementById("doprint");

		const regInt = /\d+$/;

		function add2caja(w) {
		    let row = cajita.insertRow(0);

		    let ie = document.createElement('input');
		    ie.type = 'checkbox'; ie.value = w.uid; ie.name = w.rfc || ((TICKET.TAGS.facturar == w.id_tag) && 'XXX');
		    ie.addEventListener('change', e => { if (e.target.checked) add2bag(e.target.value, e.target.name); else removeItem(e.target.value); } );
		    row.insertCell().appendChild(ie);

		    if (doprint.checked) { XHR.get('/ticket/print.lua?uid='+w.uid+'&tag='+TICKET.TAGS.ID[w.id_tag]||''); }

		    w.nombre = PEOPLE.id[w.uid.match(regInt)[0]] || 'NaP';
		    w.time = w.uid.substr(11,5);
		    w.tag = TICKET.TAGS.ID[w.id_tag];
		    w.total = (w.totalCents / 100).toFixed(2);
		    for (let k of ['time', 'nombre', 'count', 'total', 'tag']) { row.insertCell().appendChild( document.createTextNode(w[k]) ); }
		}

		function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }; //recycle?

	// SERVER-SIDE EVENT SOURCE
		function addEvents() {	
		    let esource = new EventSource(document.location.origin + ":8080");
		    DATA.onLoaded(esource);
		    esource.addEventListener("feed", function(e) {
			console.log('FEED message received\n');
			JSON.parse( e.data ).forEach( add2caja );
		    }, false);

//XXX		    caja.getByDate = e => XHR.getJSON('/caja/getDate.lua?uid='+e.target.value).then(data => {clearTable(cajita); esource.close(); data.forEach(add2caja)});
		}

	    // LOAD DBs
 		if (IDB.indexedDB)
		    IDB.loadDB( DATA ).then( () => console.log('Success!') ).then( PEOPLE.load ).then( addEvents );

	    })();

	};
