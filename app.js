
        "use strict";

	var ferre = {
	    DATA:  { VERSION: 2, DB: 'datos', STORE: 'datos-clave', KEY: 'clave', INDEX: 'desc', FILE: 'ferre.json' },
	    BAG: { VERSION: 1, DB: 'tickets', STORE: 'tickets-uid',  KEY: 'uid', INDEX: 'fecha' },
	    TICKET: { VERSION: 1, DB: 'ticket', STORE: 'ticket-clave', KEY: 'clave' },
	    PEOPLE: { VERSION: 1, DB: 'people', STORE: 'people-id', KEY: 'id', INDEX: 'nombre', FILE: 'people.json'},
	};

	window.onload = function() {
	    const persona = document.getElementById('persona');
	    const myticket = document.getElementById('ticket');
	    const TICKET = ferre.TICKET;
	    const DATA = ferre.DATA;
	    const PEOPLE = ferre.PEOPLE;
	    const DBs = [ DATA, TICKET, PEOPLE ];

	    PEOPLE.load = function loadPEOPLE() {
		let ol = document.createElement('ol');
		persona.appendChild(ol);
		IDB.readDB( PEOPLE ).openCursor( cursor => {
		    if(cursor) {
			ol.appendChild( document.createElement('li') ).textContent = cursor.value.nombre;
			cursor.continue();
		    } else {
			let ie = inputE( [['type', 'text'], ['size', 1]] );
			ie.addEventListener('keydown', printing);
			persona.appendChild( ie );
		    }
		})
	    };

	    function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; };

	    function tocents(x) { return (x / 100).toFixed(2); };

	    function topesos(x) { return (x / 100).toLocaleString('es-MX', {style:'currency', currency:'MXN'}); };

	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) };

	    function clearTable(tb) { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } };

 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	    ferre.reloadDB = function reloadDB() {
		return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) );
	    };

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
	   };

// PRINTING //

	    let printing = (function() {
		let NUMS = {};
		NUMS.C = {0: '', 1: 'CIENTO ', 2: 'DOSCIENTOS ', 3: 'TRESCIENTOS ', 4: 'CUATROCIENTOS ', 5: 'QUINIENTOS ', 6: 'SEISCIENTOS ', 7: 'SETECIENTOS ', 8: 'OCHOCIENTOS ', 9: 'NOVECIENTOS '};
		NUMS.D = {0: '', 10: 'DIEZ ', 11: 'ONCE ', 12: 'DOCE ', 13: 'TRECE ', 14: 'CATORCE ', 15: 'QUINCE ', 16: 'DIECISEIS ', 17: 'DIECISIETE ', 18: 'DIECIOCHO ', 19: 'DIECINUEVE ', 3: 'TREINTA ', 4: 'CUARENTA ', 5: 'CINCUENTA ', 6: 'SESENTA ', 7: 'SETENTA ', 8: 'OCHENTA ', 9: 'NOVENTA '}
		NUMS.I = {0: '', 1: 'UNO ', 2: 'DOS ', 3: 'TRES ', 4: 'CUATRO ', 5: 'CINCO ', 6: 'SEIS ', 7: 'SIETE ', 8: 'OCHO ', 9: 'NUEVE '};
		NUMS.M = {3: 'MIL ', 6: 'MILLON '};

		let HEADER = ['<html><head><link rel="stylesheet" href="ticket.css" media="print"></head><body><table><thead>', '', '<tr><th colspan=4>FERRETERIA AGUILAR</th></tr><tr><th colspan=4>FERRETERIA Y REFACCIONES EN GENERAL</th></tr><tr><th colspan=4>Benito Juarez No 1C  Ocotlan, Oaxaca</th></tr><tr><th colspan=4>', '', '&emsp; Tel. 57-10076</th></tr><tr class="doble"><th>CNT</th><th>DSC</th><th>PRECIO</th><th>TOTAL</th></tr></thead><tbody>']
		const STRLEN = 5;
		const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz";
		let TKT = '';

		function decenas(d,u) {
		    let ret = '';
		    switch(d) {
			case '1': return NUMS.D[d+u];
			case '2': ret += (u=='0' ? 'VEINTE ': 'VEINTI'); break;
			default: ret += NUMS.D[d] + (u == '0' ? '' : 'Y ');
		    }
		    return ret + NUMS.I[u];
		};

		function enpesos(x) {
		    let y = Math.floor( Math.log10(x) );
		    let z = x.toFixed(2);
		    let ret = '';
		    for (let i = 0; i<=y; i++) {
			let j = z[i];
			let k = y-i;
			switch(k) {
			    case 5: case 2: ret += NUMS.C[j]; break;
			    case 4: case 1: ret += decenas(j, z[++i]); break;
			    case 3: case 6: ret += ((j=='1' ? 'UN ' : NUMS.I[j]) + NUMS.M[k]); break;
			    case 0: ret += NUMS.I[j];
			}
		    }
		    ret += 'PESO(S) ' + z.substr(y+2) + '/100 M.N.'
		    return ret;
		}

		function randString() {
		    let ret = "";
		    for (let i=0; i<STRLEN; i++) { ret += ALPHA.charAt(Math.floor( Math.random() * ALPHA.length )); }
		    return ret;
		};

		function header() {
		    HEADER[3] = new Date().toLocaleString();
		    let ret = '';
		    HEADER.map( x => ret += x); //function(x) { ret += x; } );
		    return ret;
		};

		function newiframe() {
		    return new Promise( (resolve, reject) => {
			let iframe = document.createElement('iframe');
			iframe.style.visibility = "hidden";
			iframe.width = 400;
			myticket.appendChild( iframe );
			iframe.onload = resolve(iframe.contentWindow);
		    });
		}

		function printTicket( q ) {
		    let nombre = q.nombre, numero = randString();
		    TKT += '<tr><th colspan=2>'+nombre+'</th><th colspan=2 align="left">#'+numero+'</th></tr>';
		    TKT += '<tr><th colspan=4 align="center">GRACIAS POR SU COMPRA</th></tr></tfoot></tbody></table></body></html>'
		    return newiframe()
			.then( win => { let doc = win.document; doc.open(); doc.write(TKT); doc.close(); return win} )
			.then( win => win.print() )
			.then( () => myticket.removeChild(myticket.lastChild) );
		};

		function setPrint() {
		    let a = ['qty', 'rea'];
		    TKT = header();
		    let total = 0;
		    IDB.readDB( TICKET ).openCursor( cursor => {
			if (cursor) {
			    let q = cursor.value;
			    total += q.totalCents;
			    TKT += '<tr><td colspan=4>'+q.desc+'&emsp;'+q['u'+q.precio[6]]+'</td></tr><tr>';
			    a.map( function(k) { TKT += '<td align="center">'+ q[k] +'</td>'; } );
			    TKT += '<td class="pesos">'+q[q.precio].toFixed(2)+'</td><td class="pesos">'+tocents(q.totalCents)+'</td></tr>';
			    cursor.continue();
			}  else {
			    TKT += '<tfoot><tr><th colspan=4 class="total">Total de su compra: '+topesos(total)+'</th></tr>'
			    TKT += '<tr><th colspan=4>'+enpesos(total/100)+'</th></tr>'
			    persona.showModal();
			}
		    });
		};

		ferre.printDialog = function printDialog(args) { HEADER[1] = (args=='ticket' ? '' : '<tr><th colspan=4>PRESUPUESTO</th></tr>'); setPrint(); };

		return function printing(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    persona.close(k);
		    e.target.textContent = '';
		    return IDB.readDB( PEOPLE ).get( k ).then( printTicket );
		}

	    })();


// ==== BROWSING ==== //

	    (function() {

	    let sstr = '';
	    const IDBKeyRange =  window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
	    const res = document.getElementById('resultados');
            const ans = document.getElementById('tabla-resultados');
	    const N = 11;

	    function newItem(a, j) {
		let row = ans.insertRow(j);
		if (a.desc.startsWith(sstr)) { row.classList.add('encontrado'); };
		row.dataset.clave = a.clave;
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		row.insertCell().appendChild( document.createTextNode( a.clave ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		row.insertCell().appendChild( document.createTextNode( a.precio1.toFixed(2) ) );
		row.insertCell().appendChild( document.createTextNode( a.u1 ) );
	    }

	    function browsing(j, M) {
		let k = 0;
		return function(cursor) {
		    if (k == M || !cursor) { return true; }
		    newItem(cursor.value, j);
		    k++; cursor.continue();
		};
	    }

	    function searchIndex(k, type, s, M) {
		let NN = M || N;
		let t = type.substr(0,4) == 'next';
		let range = t ? IDBKeyRange.lowerBound(s, NN<N) : IDBKeyRange.upperBound(s, NN<N);
		let j = t ? -1 : 0;
		return IDB.readDB( k ).index( range, type, browsing(j, NN) );
	    }

	    function searchByDesc(s) {
		console.log('Searching by description:' + s); sstr = s;
		return searchIndex(DATA, 'next', s);
	    }

	    function searchByClave(s) {
		console.log('Searching by clave:' + s);
		return IDB.readDB( DATA ).get( asnum(s) ).then(result => searchByDesc(result ? result.desc : s), e => console.log("Error searching by clave: " + e));
	    }

	    function startSearch(e) {
		res.style.visibility='visible';
		clearTable( ans );
		searchByClave(e.target.value.toUpperCase());
		e.target.value = ""; // clean input field
	    }

	    function retrieve(t) {
		let s = ans[(t == 'prev') ? 'firstChild' : 'lastChild'].querySelector('.desc').textContent;
		searchIndex(DATA, t, s, 1).then( () => ans.removeChild((t == 'prev') ? ans.lastChild : ans.firstChild ));
	    }

 	    ferre.startSearch = startSearch;

	    ferre.keyPressed = function keyPressed(e) {
		switch (e.key || e.which) {
		    case 'Escape':
		    case 'Esc':
		    case 27:
			e.target.value = "";
			break;
		    default: break;
		}
	    };

	    ferre.scroll = function scroll(e) {
		if (e.deltaY > 0)
		    retrieve('next');
		else
		    retrieve('prev');
	    };

	    })();

// ==== TICKET ==== //

	    (function() {

	    const bag = document.getElementById('ticket-compra');
	    const ttotal = document.getElementById('ticket-total');

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

	    function uptoCents(q) { return Math.round( 100 * q[q.precio] * q.qty * (1-q.rea/100) ); };

	    function toggleTicket() {
		if (myticket.classList.toggle('visible'))
		    myticket.style.visibility = 'visible';
		else
		    myticket.style.visibility = 'hidden';
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
	    };

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

	};


