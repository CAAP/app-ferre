	var TICKET = { bagID: 'ticket-compra', myticketID: 'ticket', ttotalID: 'ticket-total', tivaID: 'ticket-iva', tbrutoID: 'ticket-bruto', tcountID: 'ticket-count' };

	(function() {
	    const VARS = ['id', 'clave', 'qty', 'rea', 'precio', 'totalCents']; // XXX
	    const EVARS = ['id', 'desc', 'qty', 'rea', 'precio', 'subTotal']; // clave
	    const XVARS = ['id', 'clave', 'qty', 'rea', 'precio', 'totalCents', 'prc', 'costol'];

	    TICKET.items = new Map();

	    const asnum = UTILS.asnum;

	    function getNodes(k) { return Array.from(TICKET.bag.querySelectorAll("[data-clave='"+k+"']")); }

	    function tocents(x) { return (x / 100).toFixed(2); }

	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); }

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
		a.forEach( o => { ret[o[0]] = o[1] } );
		return ret;
	    }

	    function bagTotal() {
		let total = 0;
		TICKET.items.forEach( item => { total += parseInt(item.totalCents); } );
		TICKET.total( UTILS.redondeo(total) );
	    }

	    function precios(q) {
		if ((q.precio2 == 0) && (q.precio3 == 0)) { return document.createTextNode( q.precios.precio1 ); }
		let ret = document.createElement('select');
		ret.addEventListener('change', TICKET.update);
		ret.name = 'precio';
		for (let k in q.precios) {
		    let opt = document.createElement('option');
		    opt.value = k; opt.selected = (q.precio == k);
		    opt.appendChild( document.createTextNode( q.precios[k] ) );
		    ret.appendChild(opt);
		}
		return ret;
	    }

	    function israbatt2(q, row, prev) {
		let clave = asnum( row.dataset.clave );
		let nodes = getNodes(clave);

		let rabatt = parseFloat(q.rea) > 0 || q.precio != 'precio1';
		if (rabatt ^ prev) {
		    if (rabatt)
			nodes.forEach(tr => tr.classList.add('rabatt'));
		    else
			nodes.forEach(tr => tr.classList.remove('rabatt'));
		}
	    }

	    function israbatt(q, row, prev) {
		let rabatt = parseFloat(q.rea) > 0 || q.precio != 'precio1';
		if (rabatt ^ prev) {
		    if (rabatt)
			row.classList.add('rabatt');
		    else
			row.classList.remove('rabatt');
		}
	    }

	    function displayItem(q) {
		let row = TICKET.bag.insertRow(0);
//		row.title = q.desc.substr(0,3); // TRYING OUT LOCATION XXX
		row.dataset.clave = q.clave;
		israbatt(q, row, false);
		// DATOS
		row.insertCell().appendChild( document.createTextNode( q.id ) ); // q.clave XXX
		row.insertCell().appendChild( inputE( [['type', 'number'], ['size', 2], ['min', 0], ['name', 'qty'], ['value', q.qty]] ) ).select();
		let desc = row.insertCell();
		if (q.faltante) { desc.classList.add('faltante'); }
		desc.appendChild( document.createTextNode( q.desc ) );
		let pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		let rea = inputE( [['type', 'number'], ['size', 2], ['name', 'rea'], ['value', q.rea]] );
		let td = row.insertCell(); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		let total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
	    }

/*
 *

	    function toggleView( e ) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		let fun = e.target.dataset.fun;
		let items = TICKET.items;
		let q = items.get( clave );
		q.checado = !q.checado;
		items.set( clave, q );
		getNodes(clave).forEach( tr => TICKET.bag.removeChild(tr) );
		TICKET.add(q);
	    }
*
*/

	    function reassure( e ) {
		if (window.confirm('Quieres eliminar un producto?'))
		    TICKET.remove( e.target.parentElement );
	    }

	    function displayItem2(q) {
		let row = TICKET.bag.insertRow(0);
		row.classList.add('bold');
//		row.title = q.desc.substr(0,3); // TRYING OUT LOCATION XXX
		row.dataset.clave = q.clave;
		// DATOS INFO
		let uid = row.insertCell();
		uid.appendChild( document.createTextNode( q.id ) ); // q.clave XXX
//		uid.classList.add('highlight');
//		uid.ondblclick = toggleView;
		let desc = row.insertCell();
		desc.colSpan = 2;
		if (q.faltante) { desc.classList.add('faltante'); }
		desc.appendChild( document.createTextNode( q.desc ) );
		if (TICKET.lookUp) { desc.onclick = () => { UTILS.clearTable( BROWSE.lis ); BROWSE.doSearch( q.clave ); }; }
		// TRASH
		let trash = row.insertCell();
		trash.classList.add('trashout'); trash.appendChild( document.createTextNode( ' ' ) );
		trash.onclick = reassure;
//	BREAK
		row = TICKET.bag.insertRow(1);
		row.dataset.clave = q.clave;
		// DATOS 4 CHANGE
		row.insertCell().appendChild( inputE( [['type', 'number'], ['size', 2], ['min', 0], ['name', 'qty'], ['value', q.qty]] ) ).select();
		let pcs = row.insertCell();
		pcs.classList.add('pesos'); pcs.appendChild( precios(q) );
		let rea = inputE( [['type', 'number'], ['size', 2], ['name', 'rea'], ['value', q.rea]] );
		let td = row.insertCell(); td.classList.add('pesos'); td.appendChild(rea); td.appendChild( document.createTextNode('%'));
		// TOTAL
		let total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
		// RABATT
		israbatt2(q, row, false);
	    }

	    function displayMissing(q) {
		let row = TICKET.bag.insertRow(0);
		row.classList.add('bold');
//		row.title = q.desc.substr(0,3); // TRYING OUT LOCATION XXX
		row.dataset.clave = q.clave;
		// DATOS INFO
		let uid = row.insertCell();
		uid.appendChild( document.createTextNode( q.id ) ); // q.clave XXX
//		uid.classList.add('highlight');
//		uid.ondblclick = toggleView;
		let desc = row.insertCell();
		desc.colSpan = 2;
		if (q.faltante) { desc.classList.add('faltante'); }
		desc.appendChild( document.createTextNode( q.desc ) );
		if (TICKET.lookUp) { desc.onclick = () => { UTILS.clearTable( BROWSE.lis ); BROWSE.doSearch( q.clave ); }; }
		// TRASH
		let trash = row.insertCell();
		trash.classList.add('trashout'); trash.appendChild( document.createTextNode( ' ' ) );
		trash.onclick = reassure;
//	BREAK
		row = TICKET.bag.insertRow(1);
		row.dataset.clave = q.clave;
		// DATOS 4 CHANGE
		let miss = row.insertCell(); miss.colSpan = 4;
		miss.appendChild( inputE( [['type', 'text'], ['size', 25], ['name', 'obs'], ['value', q.obs]] ) ).select();
	    }

	    function showItem(q) {
		let row = TICKET.bag.insertRow();
		row.dataset.clave = q.clave;
		israbatt(q, row, false);
		// DATOS
		q.subTotal = tocents(q.totalCents);
		q.prc = q.precios[q.precio];
		EVARS.forEach( v => row.insertCell().appendChild( document.createTextNode( q[v] ) ) );
		row.lastChild.classList.add('total');
	    }

	    function formatted( r, v ) {
		r.classList.add('pesos');
		r.appendChild( document.createTextNode(v) );
	    }

	    function showItem2(q) {
		let row = TICKET.bag.insertRow(-1);
		row.classList.add('bold');
		row.dataset.clave = q.clave;
		// DATOS INFO
		row.insertCell().appendChild( document.createTextNode( q.id ) ); // q.clave XXX
		let desc = row.insertCell();
		desc.colSpan = 2;
		if (q.faltante) { desc.classList.add('faltante'); }
		desc.appendChild( document.createTextNode( q.desc ) );
		// TRASH
		let trash = row.insertCell();
		trash.classList.add('trashout'); trash.appendChild( document.createTextNode( ' ' ) );
		trash.onclick = reassure;
//	BREAK
		row = TICKET.bag.insertRow(-1);
		row.dataset.clave = q.clave;
		// DATOS 4 CHANGE
		formatted( row.insertCell(), q.qty );
		formatted( row.insertCell(), q.precios[q.precio] );
		formatted( row.insertCell(), q.rea + ' %' );
		// TOTAL
		let total = row.insertCell();
		total.classList.add('pesos'); total.classList.add('total'); total.appendChild( document.createTextNode( tocents(q.totalCents) ) );
		// RABATT
//		israbatt2(q, row, false);
	    }

	    function showTaxes(q) {
		let row = TICKET.bag.insertRow();
		row.dataset.clave = q.clave;
		israbatt(q, row, false);
		// DATOS
		q.subTotal = tocents(q.totalCents/1.16);
		q.prc = q.precios[q.precio].replace(/[\d\.]+/, n => (n/1.16).toFixed(2));
		EVARS.forEach( v => row.insertCell().appendChild( document.createTextNode( q[v] ) ) );
		row.lastChild.classList.add('total');
		if (q.uidSAT) {
		    let row = TICKET.bag.insertRow();
		    row.dataset.clave = q.clave;
		    let satinfo = row.insertCell();
		    satinfo.appendChild( document.createTextNode(q.uidSAT) );
		    satinfo.colSpan = 2;
		}
	    }

	    TICKET.plain = o => VARS.map( v => { return (v + '+' + o[v] || '') } ).join('+');

	    TICKET.xplain = function(o) {
		o.prc = o.precios[o.precio];
		return XVARS.map( v => { return (v + '+' + o[v] || '') } ).join('+');
	    };

	    TICKET.update = function(e) {
		let tr = e.target.parentElement.parentElement;
		let lbl = tr.querySelector('.total');
		let clave = asnum( tr.dataset.clave );
		let k = e.target.name;
		let v = asnum( e.target.value );
		let items = TICKET.items;

		e.target.value = v;

		if (k == 'qty' && v == 0) { return TICKET.remove(tr); }

		if (items.has( clave )) {
		    let q = items.get( clave );
		    let rabatt = (q.rea > 0 || q.precio != 'precio1');
		    q[k] = v;
		    israbatt2(q, tr, rabatt);
		    q.totalCents = uptoCents(q); // partial total
		    items.set( clave, q );
		    lbl.textContent = tocents(q.totalCents);
		    bagTotal();
		    return clave; // FIX for caja.js XXX
		}
	    };

/*
	    TICKET.update = function(e) {
		let tr = e.target.parentElement.parentElement;
//		let lbl = tr.querySelector('.total');
		let clave = asnum( tr.dataset.clave );
		let k = e.target.name;
		let v = asnum( e.target.value );
		let items = TICKET.items;

		e.target.value = v;

		if (k == 'qty' && v == 0) { return TICKET.remove(tr); }

		if (items.has( clave )) {
		    let q = items.get( clave );
		    let rabatt = (q.rea > 0 || q.precio != 'precio1');
		    q[k] = v;
		    israbatt2(q, tr, rabatt);
		    q.totalCents = uptoCents(q); // partial total
		    items.set( clave, q );
//		    lbl.textContent = tocents(q.totalCents);
		    bagTotal();
		    return clave; // FIX for caja.js XXX
		}
	    };
*/

	    TICKET.add = function(w) {
		TICKET.myticket.style.visibility = 'visible';
		TICKET.items.set( w.clave, w );
		if (ferre.MISS)
		    displayMissing( w );
		else {
		    displayItem2( w );
		    bagTotal();
		}

	    };
		
	    TICKET.show = function(w) {
		TICKET.myticket.style.visibility = 'visible';
		TICKET.items.set( w.clave, w );
		showItem2( w );
		bagTotal();
	    };

	    TICKET.taxes = function(w) {
		TICKET.myticket.style.visibility = 'visible';
		TICKET.items.set( w.clave, w );
		showTaxes( w );
	    };

	    TICKET.remove = function(tr) {
		let clave = asnum( tr.dataset.clave );
		TICKET.items.delete( clave );

		getNodes(clave).forEach( tr => TICKET.bag.removeChild(tr) );

		if (!TICKET.bag.hasChildNodes()) { TICKET.empty(); } else { bagTotal(); }
		return clave; // FIX for caja.js XXX
	    };

	    TICKET.empty = function() { TICKET.items.clear(); UTILS.clearTable( TICKET.bag ); TICKET.myticket.style.visibility = 'hidden'; TICKET.extraEmpty(); };

	    })();


