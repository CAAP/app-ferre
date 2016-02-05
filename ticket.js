        "use strict";

	(function() {
	    const bag = document.getElementById('ticket-compra');
	    const ttotal = document.getElementById('ticket-total');
	    const myticket = document.getElementById('ticket');
	    const N = 11;
	    const TICKET = ferre.TICKET;
	    const DATA = ferre.DATA;

	    TICKET.load = function loadTICKET() {
		var objStore = readDB( TICKET );
		var req = objStore.count();
		req.onsuccess = function(e) {
		    if (req.result > 0) {
			toggleTicket();
			var total = 0;
			objStore.openCursor().onsuccess = function(ev) {
			    var cursor = ev.target.result;
			    if (cursor) {
				total += cursor.value.totalCents;
			        displayItem( cursor.value );
		    	        cursor.continue();
			    } else { ttotal.textContent = tocents( total ); }
			};
		    }
		};
	    };

	    var asnum = function asnum(s) { var n = Number(s); return Number.isNaN(n) ? s : n; };

	    var tocents = function tocents(x) { return (x / 100).toFixed(2); };

	    var uptoCents = function(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    var transaction = function transaction(t) {
		return function initTransaction( k ) {
		    var trn = k.CONN.transaction(k.STORE, t);
		    trn.oncomplete = function(e) { console.log(t +' transaction successfully done.'); };
		    trn.onerror = function(e) { console.log( t + ' transaction error:' + e.target.errorCode); };
		    return trn.objectStore(k.STORE);
		};
	    };

	    var write2DB = transaction("readwrite");

	    var readDB = transaction("readonly");

	    var clearTable = function(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

	    var toggleTicket = function toggleTicket() {
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    myticket.style.visibility = 'hidden';
	    }

	    var bagTotal = function bagTotal() {
		var total = 0;
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if (cursor) {
			total += cursor.value.totalCents;
			cursor.continue();
		    } else { ttotal.textContent = tocents( total ); }
		};
	    };

	    var incdec = function incdec(e) {
		switch (e.key || e.which) {
		    case '+':
		    case 'Add':
		    case 187:
			e.target.value++;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    case '-':
		    case 'Subtract':
		    case 189:
			if (e.target.value == 1) { e.preventDefault(); break; }
			e.target.value--;
			e.preventDefault();
			ferre.updateItem(e);
			break;
		    default: break;
		}
	    }

	   var inputE = function inputE( a ) {
		var ret = document.createElement('input');
		ret.addEventListener('keydown', incdec);
		a.map( function(o) { ret[o.k] = o.v;});
		return ret;
	   };

	    var precios = function precios(q) {
		if ((q.precio2 == 0) && (q.precio3 == 0)) { return document.createTextNode( q.precio1.toFixed(2) ); }
		var ret = document.createElement('select');
		ret.name = 'precio';
		for(var i=1;i<4;i++) {
		    var k = 'precio'+i;
		    if (q[k] > 0) {
			var opt = document.createElement('option');
			opt.value = k; opt.selected = (q.precio == k);
			opt.appendChild( document.createTextNode( q[k] + ' / ' + q['u'+i]) );
			ret.appendChild(opt);
		    }
		}
		return ret;
	    }

	    var displayItem = function displayItem(q) {
		var row = bag.insertRow();
		row.dataset.clave = q.clave;
		var qty = row.insertCell().appendChild( inputE( [{k:'type', v:'text'}, {k:'size', v:2}, {k:'name', v:'qty'}, {k:'value', v:q.qty}] ) );
		var desc = row.insertCell();
		desc.classList.add('basura'); desc.appendChild( document.createTextNode( q.desc ) );
		var pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		var rea = inputE( [{k:'type', v:'text'}, {k:'size', v:2}, {k:'name', v:'rea'}, {k:'value', v:q.rea}] );
		var td = row.insertCell(); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		var total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
	    };

	    var item2ticket = function item2ticket(q) {
		var objStore = write2DB( TICKET )
		var req = objStore.get( q.clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(e) {
		    if (e.target.result) { console.log('Item is already in the bag.'); }
		    else {
			q.qty =  1; q.precio = 'precio1'; q.rea = 0; q.totalCents = uptoCents(q);
			var reqUpdate = objStore.put( q );
			reqUpdate.onerror = function(e) { console.log('Error adding item to ticket.'); };
			reqUpdate.onsuccess = function(e) { displayItem(q); bagTotal(); };
		    }
		};
	    };

	    ferre.add2bag = function add2bag(e) {
		var clave = asnum( e.target.parentElement.dataset.clave );
		(myticket.classList.contains('visible') || toggleTicket());
		var req = readDB( DATA ).get( clave );
		req.onsuccess = function(e) {
		    var q = e.target.result;
		    item2ticket(q);
		};
	    };

	    ferre.updateItem = function updateItem(e) {
		var tr = e.target.parentElement.parentElement;
		var lbl = tr.querySelector('.total');
		var clave = asnum( tr.dataset.clave );
		var k = e.target.name;
		var v = e.target.value;

		console.log( 'Update ' + clave + ' -> ' + k + ': ' + v);

		var objStore = write2DB( TICKET )
		var req = objStore.get( clave );
		req.onerror =  function(e) { console.log('Error searching item in ticket.'); };
		req.onsuccess = function(ev) {
		    var q = this.result;
		    q[k] = asnum( v ); // FORCE cast to NUMBER
		    q.totalCents = uptoCents(q); // UPDATE partial TOTAL
		    var reqUpdate = objStore.put( q );
		    reqUpdate.onerror = function(eve) { console.log( 'Error updating item in ticket.' ); };
		    reqUpdate.onsuccess = function(eve) { lbl.textContent = tocents( q.totalCents ); bagTotal(); };
		};
	    };

	    ferre.item2bin = function item2bin(e) {
		var clave = asnum( e.target.parentElement.dataset.clave );
		var tr = e.target.parentElement;
		var req = write2DB( TICKET ).delete( clave );
		req.onsuccess = function(ev) {
		    bag.removeChild( tr );
		    if (!bag.hasChildNodes()) { toggleTicket(); } else { bagTotal(); }
		};
	    };

	    ferre.emptyBag = function emptyBag(e) {
		var req = write2DB( TICKET ).clear()
		req.onsuccess = function(ev) {
		    clearTable( bag );
		    toggleTicket();
		};
	    };
	})();

