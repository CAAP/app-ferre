	"use strict";

	var TICKET = { VERSION: 1, DB: 'ticket', STORE: 'ticket-clave', KEY: 'clave', bagID: 'ticket-compra', ttotalID: 'ticket-total', myticketID: 'ticket', tivaID: 'ticket-iva', tbrutoID: 'ticket-bruto' };

	(function() {
	    const VARS = ['clave', 'precio', 'rea', 'qty', 'totalCents'];
	    const TAGS = {none: 'x', presupuesto: 'a', imprimir: 'b', facturar: 'c', guardar: 'g', impreso: 'I', pagado: 'P', facturado: 'F'};
	    TAGS.ID = {x: 'none', a: 'presupuesto', b: 'imprimir', c: 'facturar', g: 'guardar'};

	    TICKET.TAGS = TAGS;

	    TICKET.load = function() {
		let objStore = IDB.readDB( TICKET );
		objStore.count().then( result => {
		    if (!(result>0)) { return; }
		    toggleTicket();
		    let total = 0;
		    return objStore.openCursor( cursor => {
			if (cursor) {
			    total += asnum(cursor.value.totalCents);
			    displayItem( cursor.value );
		    	    cursor.continue();
			} else { TICKET.total( total ); }
		    });
		});
	    };

	    function tocents(x) { return (x / 100).toFixed(2); };

	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    function incdec(e) {
		switch (e.key || e.which) {
		    case '+':
		    case 'Add':
		    case 187: case 107:
			e.target.value++;
			e.preventDefault();
			TICKET.update(e); //ferre.updateItem(e);
			break;
		    case '-':
		    case 'Subtract':
		    case 189: case 109:
			if (e.target.value == 1) { e.preventDefault(); break; }
			e.target.value--;
			e.preventDefault();
			TICKET.update(e); //ferre.updateItem(e);
			break;
		    default: break;
		}
	    }

	    function inputE( a ) {
		let ret = document.createElement('input');
		ret.addEventListener('keydown', incdec);
		a.map( o => ret[o[0]] = o[1] );
		return ret;
	    }

	    function toggleTicket() {
		let myticket = TICKET.myticket;
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    myticket.style.visibility = 'hidden';
	    }

	    function bagTotal(objStore) {
		let total = 0;
		return objStore.openCursor( cursor => {
		    if (cursor) {
			total += asnum(cursor.value.totalCents);
			cursor.continue();
		    } else { TICKET.total( total ); } // TICKET.ttotal.textContent = tocents( total );
		});
	    }

	    function precios(q) {
		if ((q.precio2 == 0) && (q.precio3 == 0)) { return document.createTextNode( q.precio1.toFixed(2) ); }
		let ret = document.createElement('select');
		ret.name = 'precio';
		for(let i=1;i<4;i++) {
		    let k = 'precio'+i;
		    if (q[k] > 0) {
			let opt = document.createElement('option');
			opt.value = k; opt.selected = (q.precio == k);
			opt.appendChild( document.createTextNode( q[k] + ' / ' + q['u'+i]) );
			ret.appendChild(opt);
		    }
		}
		return ret;
	    }

	    function displayItem(q) {
		let row = TICKET.bag.insertRow();
		row.dataset.clave = q.clave;
		let qty = row.insertCell().appendChild( inputE( [['type', 'text'], ['size', 2], ['name', 'qty'], ['value', q.qty]] ) );
		let desc = row.insertCell();
		desc.classList.add('basura'); desc.appendChild( document.createTextNode( q.desc ) );
		let pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		let rea = inputE( [['type', 'text'], ['size', 2], ['name', 'rea'], ['value', q.rea]] );
		let td = row.insertCell(); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		let total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
	    }

	    TICKET.obj = x => VARS.reduce( (o,v) => { o[v] = x[v]; return o; }, {} );

	    TICKET.update = function(e) {
		let tr = e.target.parentElement.parentElement;
		let lbl = tr.querySelector('.total');
		let clave = asnum( tr.dataset.clave );
		let k = e.target.name;
		let v = asnum( e.target.value );

		console.log( clave + ' - ' + k + ': ' + v);

		let objStore = IDB.write2DB( TICKET )
		return objStore.get( clave ).then( q => {
			q[k] = v;
			q.totalCents = uptoCents(q); // partial total
			return q;
		    }, e => console.log("Error searching item in ticket: " + e) )
		.then( objStore.put )
		.then( q => { lbl.textContent = tocents(q.totalCents); return q; }, e => console.log("Error updating item in ticket: " + e) )
		.then( () => bagTotal(objStore) );
	    };

	    TICKET.add = function(w) {
		(TICKET.myticket.classList.contains('visible') || toggleTicket());
		return IDB.write2DB( TICKET ).put( w )
			.then( displayItem )
			.then( () => bagTotal(IDB.readDB( TICKET )) );
	    };

	    TICKET.remove = function(tr) {
		let clave = asnum( tr.dataset.clave );
		let objStore = IDB.write2DB( TICKET )
		return objStore.delete( clave ).then( () => {
		    TICKET.bag.removeChild( tr );
		    if (!TICKET.bag.hasChildNodes()) { toggleTicket(); } else { bagTotal(objStore); }
		});
	    };

	    TICKET.empty = function(e) { return IDB.write2DB( TICKET ).clear().then( () => { clearTable( TICKET.bag ); toggleTicket(); }); };

	    })();


