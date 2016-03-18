// ==== TICKET ==== //

	    (function() {

	    const bag = document.getElementById('ticket-compra');
	    const ttotal = document.getElementById('ticket-total');
	    const myticket = document.getElementById('ticket');
	    const TICKET = ferre.TICKET;
	    const DATA = ferre.DATA;
	    const STRLEN = 5;
	    const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz";

	    TICKET.load = function() {
		let objStore = IDB.readDB( TICKET );
		objStore.count().then( result => {
		    if (!(result>0)) { return; }
		    toggleTicket();
		    let total = 0;
		    return objStore.openCursor( cursor => {
			if (cursor) {
			    total += cursor.value.totalCents;
			    displayItem( cursor.value );
		    	    cursor.continue();
			} else { ttotal.textContent = tocents( total ); }
		    });
		});
	    };

	    function tocents(x) { return (x / 100).toFixed(2); };

	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    function randString() {
		    let ret = "";
		    for (let i=0; i<STRLEN; i++) { ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length )); }
		    return ret;
	    }

	    function incdec(e) {
		switch (e.key || e.which) {
		    case '+':
		    case 'Add':
		    case 187: case 107:
			e.target.value++;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    case '-':
		    case 'Subtract':
		    case 189: case 109:
			if (e.target.value == 1) { e.preventDefault(); break; }
			e.target.value--;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    default: break;
		}
	    }

	    function inputE( a ) {
		let ret = document.createElement('input');
		ret.addEventListener('keydown', incdec);
		a.map( o => ret[o[0]] = o[1] ); //  function(o) { ret[o[0]] = o[1];});
		return ret;
	    }

	    function toggleTicket() {
		if (TICKET.ID.length == 0)
		    TICKET.ID = randString();
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    { myticket.style.visibility = 'hidden'; TICKET.ID = ''; }
	    }

	    function bagTotal(objStore) {
		let total = 0;
		return objStore.openCursor( cursor => {
		    if (cursor) {
			total += cursor.value.totalCents;
			cursor.continue();
		    } else { ttotal.textContent = tocents( total ); }
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
		let row = bag.insertRow();
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

	    ferre.add2bag = function(e) {
		let clave = asnum( e.target.parentElement.dataset.clave );
		(myticket.classList.contains('visible') || toggleTicket());
		return IDB.readDB( TICKET ).get( clave ).then( q => {
		    if (q) { console.log("Item is already in the bag."); return; }
		    return IDB.readDB( DATA ).get( clave )
			.then( w => { w.qty = 1; w.precio = 'precio1'; w.rea = 0; w.totalCents = uptoCents(w); return w })
			.then( q => IDB.write2DB( TICKET ).put(q) )
			.then( displayItem )
			.then( () => bagTotal(IDB.readDB( TICKET )) ) });
	    };

	    ferre.updateItem = function(e) {
		let tr = e.target.parentElement.parentElement;
		let lbl = tr.querySelector('.total');
		let clave = asnum( tr.dataset.clave );
		let k = e.target.name;
		let v = e.target.value;

		console.log( clave + ' - ' + k + ': ' + v);

		let objStore = IDB.write2DB( TICKET )
		return objStore.get( clave ).then( q => {
			q[k] = asnum(v); // cast to NUMBER
			q.totalCents = uptoCents(q); // partial total
			return q;
		    }, e => console.log("Error searching item in ticket: " + e) ).then( objStore.put ).then( q => {
			lbl.textContent = tocents(q.totalCents); return true;
		    }, e => console.log("Error updating item in ticket: " + e) ).then( () => bagTotal(objStore) );
	    };

	    ferre.item2bin = function(e) {
		let clave = asnum( e.target.parentElement.dataset.clave );
		let tr = e.target.parentElement;
		let objStore = IDB.write2DB( TICKET )
		return objStore.delete( clave ).then( () => {
		    bag.removeChild( tr );
		    if (!bag.hasChildNodes()) { toggleTicket(); } else { bagTotal(objStore); }
		});
	    };

	    ferre.emptyBag = function(e) { return IDB.write2DB( TICKET ).clear().then( () => { clearTable( bag ); toggleTicket(); }); };

	    })();


