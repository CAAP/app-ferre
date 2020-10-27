	// HEADER
	(function() {
	    let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
	    document.getElementById('notifications').innerHTML = now(FORMAT);
	    document.getElementById("eventos").innerHTML = 'Loading ...'
	    document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 3.0 + ' | cArLoS&trade; &copy;&reg;';
	})();

	// ADMIN
	(function() {
	    admin.origin = document.location.origin+':5040/';

	    DATA.inplace = q => {
		let r = document.body.querySelector('tr[data-clave="'+q.clave+'"]');
		if (r) {
		    if (!q.desc.includes('VV')) {
			UTILS.clearTable(r);
			BROWSE.rows(q,r);
		    }
		    r.classList.add('updated');
		}
		return q;
	    };

	    let mymenu = document.getElementById("menu");

	    admin.menuToggle = p => { mymenu.style.display = p ? 'inline' : 'none'; };
	})();

	// Init & Load DBs
	(function() {
	    const STORES = DATA.STORES;
	    let lvers = document.getElementById('db-vers');
	    STORES.VERS.inplace = o => { lvers.textContent = o.week + 'V' + o.vers; return true; };

	    function isPriceless(store) {
		if (store.STORE == 'precios')
		    return XHR.getJSON(admin.origin+'json/version.json')
			      .then( STORES.VERS.update );
		else
		    return Promise.resolve(true);
	    }

	    function ifLoad(k) { return IDB.readDB(k).count().then(
		q => { if (q == 0 && k.FILE)
			    return IDB.populateDB(k).then(() => isPriceless(k) );
			else
			    return Promise.resolve(true);
		     }
	        );
	    }

	    document.getElementById('pacman').style.visibility = 'visible';
	    if (IDB.indexedDB)
		IDB.loadDB( DATA )
		   .then(db => Promise.all(UTILS.mapObj(STORES, k => {
			const store = STORES[k];
			if (store.INDEX == undefined) // case of STORES that have no actual DB on disk
			    return Promise.resolve(true);
			else {
			    store.CONN = db.CONN;
			    return ifLoad(store);
			}
		   })))
		   .then(() => { STORES.PRICE.INDEX = 'desc'; });

	})();

	// BROWSE
	(function() {
	    const PRICE = DATA.STORES.PRICE;
	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

	    BROWSE.DBget = s => IDB.readDB( PRICE ).get( s );
	    BROWSE.DBindex = (a, b, f) => IDB.readDB( PRICE ).index( a, b, f );

	    BROWSE.query = o => admin.xget('query', o);

	    BROWSE.rows = function(a, row) {
		row.insertCell().appendChild( document.createTextNode( a.fecha ) );
		let clave = row.insertCell();
		clave.classList.add('pesos'); clave.appendChild( document.createTextNode( a.clave ) );
		let sat = row.insertCell();
		clave.classList.add('pesos'); sat.appendChild( document.createTextNode( a.uidSAT || '' ) );
		let desc = row.insertCell(); // class 'desc' necessary for scrolling
		if (a.faltante) { desc.classList.add('faltante'); }
		desc.classList.add('desc'); desc.appendChild( document.createTextNode( a.desc ) );
		let costol = row.insertCell();
		costol.classList.add('total'); costol.classList.add('precio1');
		costol.appendChild( document.createTextNode( (a.costol / 1e4).toFixed(2) ) );
	    };

	    admin.keyPressed = BROWSE.keyPressed;
	    admin.startSearch = BROWSE.startSearch;
	    admin.scroll = BROWSE.scroll;
	})();

	// UPDATES
	(function() {
	    let tabla = document.getElementById('tabla-cambios');
	    let tkt = document.getElementById('ticket');
	    let cpb = document.getElementById('clipboard');
	    let costos = new Set(['costo', 'costol', 'impuesto', 'descuento', 'rebaja', 'prc1', 'prc2', 'prc3']);
	    let records = new Map()
	    let fields = new Set();
	    let suppliers = new Map();
	    let unit1 = new Map();
	    let unit2 = new Map();
	    let unit3 = new Map();
	    let units = new Map([['u1', unit1], ['u2', unit2], ['u3', unit3]]);
	    let UNITS = [];
	    let CLIP = false;

	    let asnum = UTILS.asnum;

	    function setPen(e) {
		if (CLIP && (e.target.tagName != 'INPUT')) {
		    const clave = asnum(tkt.dataset.clave);
		    let ie = e.target.firstChild;
		    let k = ie.name;
		    let v = CLIP[k] || '';
		    CHANGES.update(clave, k, v);
		    ie.value = v;
		    ie.classList.add('modificado');
		}
	    }

	    function inputs(row, k, isClip) {
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 7; ie.name = k; ie.disabled = true; // ie.size = 7;
		let cell = row.insertCell(); cell.appendChild( ie );
		if (isClip) { cell.classList.add('pen'); cell.onclick = setPen; }
		fields.add( k );
		return ie;
	    }

	    function setClip(e) {
		let clave = asnum(e.target.firstChild.value);
		if (records.has( clave )) {
		    CLIP = records.get( clave );
		    cpb.innerText = CLIP.clave + ' : ' + CLIP.desc.substr(0, 30);
		}
	    }

	    function choices(s, b) {
		let opt = document.createElement('option');
		opt.value = s;
		opt.appendChild(document.createTextNode(s));
		opt.selected = b;
		return opt;
	    }

	    function selects(lbl, cell, f) {
		let ch = document.createElement('select'); ch.name = lbl;
		cell.appendChild( ch ); f(ch, lbl);
		return ch;
	    }

	    function getSuppliers(el) {
		return XHR.getJSON('/json/proveedores.json').then( a => {
		    const ch = choices('', true); el.appendChild( ch );
		    suppliers.set('none', ch);
		    return Promise.resolve(a);
		} ).then( a => a.forEach( p => {
		    const ch = choices(p.nombre, false);
		    suppliers.set(p.nombre, ch); el.appendChild( ch );
	// XXX XXX XXX
		    el.parentElement.appendChild( document.createTextNode('') );
		} ) );
	    }

	    function getUnits(el, lbl) {
		const ch = choices('', true); el.appendChild( ch );
		units.get(lbl).set('none', ch);
		UNITS.forEach( u => {
		    const ch = choices(u.unidad, false); ch.title = u.desc;
		    units.get(lbl).set(u.unidad, ch); el.appendChild( ch );
	// XXX XXX XXX
		    el.parentElement.appendChild( document.createTextNode('') );
		} );
	    }

	    function clearChoices() {
		[suppliers, unit1, unit2, unit3].forEach( m => m.get('none').selected = true);
	// XXX XXX XXX
		[suppliers, unit1, unit2, unit3].forEach( m => {
	m.get('none').parentElement.parentElement.lastChild.replaceWith(document.createTextNode(''));
		} );
	    }

	    admin.reset = () => {
		UTILS.clearTable( tabla );
		clearChoices();
		tkt.style.visibility = 'visible';
	    };

	    function derived() {
		const ie = document.createElement('input'); ie.type = 'text';
		ie.size = 4; ie.name = lbl+'_p'; ie.disabled = true;
		el.parentElement.appendChild(document.createTextNode(' de '));
		el.parentElement.appendChild( ie );
	    }

	    function setChoice(v, m) {
		if (v && m.has(v)) {
		    m.get(v).selected = true;
		//XXX XXX XXX
	m.get('none').parentElement.parentElement.lastChild.replaceWith(document.createTextNode(''));
		}
		else {
		    m.get('none').selected = true;
		//XXX XXX XXX
	m.get('none').parentElement.parentElement.lastChild.replaceWith(document.createTextNode(v || ''));
		}
	    }

	    function setfields( o ) {
		tkt.dataset.clave = o.clave;
		let costol = o.costol
		let a = Object.assign({}, o, {costol: (costol/1e4).toFixed(2)});
		Array.from(fields).filter( k => k.startsWith('prc') ).forEach( k => {a[k.replace('prc', 'precio')] = (a[k]*costol/1e4).toFixed(2)} );
		fields.forEach( k => {tabla.querySelector('input[name='+k+']').value = a[k] || '' } );
		// choices
		setChoice(o.proveedor, suppliers);
		units.forEach((u, k) => setChoice(o[k], u));
	    }

	    function fetch(k, f) {
		if (records.has(k)) {
//		    CHANGES.inplace(k, m => tabla.querySelector('input[name='+m+']').classList.add('modificado'));
		    return f( CHANGES.fetch(k, records.get(k)) );
		} else
		return admin.xget('query', {clave: k, fruit: sessionStorage.fruit});
	    }

	    function costol(o) { o.costol = o.costo*(100+(Number(o.impuesto)||0))*(100-(Number(o.descuento)||0))*(1-(Number(o.rebaja)||0)/100) }

	    function compute(clave, k) {
		if (k.startsWith('prc'))
		    fetch(clave, setfields);
		else
		    fetch( clave, w => { costol(w); records.set(clave,w); setfields(w); } );
	    }

	    let cleanMark = () => tkt.querySelectorAll('.modificado').forEach(i => {i.classList.remove('modificado')});

	    admin.getRecord = function(e) {
		let clave = asnum(e.target.parentElement.dataset.clave);
		fetch(clave, setfields);
	    };

	    admin.nuevo = () => admin.xget('query', {desc: 'VV*', fruit: sessionStorage.fruit});

	    admin.setRecord = function(a) {
		cleanMark();
		records.set(a.clave, a);
		setfields(a);
	    };

	    admin.cancelar = () => {
		records.clear();
		CHANGES.clear();
		cleanMark();
		tkt.querySelectorAll('input').forEach(i => { i.value = ''});
		tkt.dataset.clave = '';
		clearChoices();
	    };

	    admin.anUpdate = function(e) {
		const clave = asnum(tkt.dataset.clave);
		e.target.classList.add('modificado');
		let k = e.target.name;
		let v = e.target.value;
		if ((k=='desc') && v.includes('VVV'))
		    alert('Si deseas eliminar esta clave haz click en "eliminar"!');
		CHANGES.update(clave, k, v);
		if (costos.has(k)) { compute(clave, k); }
	    };

	    //
	    function update(clave, o) {
		if (o.desc) { o.desc = o.desc.replace(/\s+$/, '').replace(/^\s+/, ''); }
		return XHR.get(admin.origin + 'update?' + UTILS.encPpties(Object.assign(o,{clave: clave}))); // , tbname: 'datos', fruit: sessionStorage.fruit
	    }

	    admin.eliminar = () => {
		const clave = tkt.dataset.clave;    
		if (window.confirm('Estas seguro de eliminar la clave ' + clave + '?'))
		    XHR.get(admin.origin + 'eliminar?clave=' + clave)
		    .then( admin.cancelar );
	    };

	    admin.enviar = function(fecha) {
		const clave = asnum(tkt.dataset.clave);
		if (fecha)
		    CHANGES.update(clave, 'fecha', true);
		if (window.confirm('Estas seguro de realizar los cambios?'))
		    CHANGES.get(clave, update)
		    .then( admin.cancelar );
	    };

	    function addField(k) {
		if (k.startsWith('u')) { return; } // already taken into account by prc_ (u1, u2, u3) & proveedor (uidPROV)
		let row = tabla.insertRow();
		// input && defaults
		row.insertCell().appendChild( document.createTextNode(k.replace('prc', 'precio')) );
		let cell = row.insertCell();
		let ie = document.createElement('input');
		ie.type = 'text'; ie.size = 8; ie.name = k;
		// specifics
		switch(k) {
		    case 'desc':  ie.size = 40; cell.colSpan = 3; cell.style.paddingRight = "40px";
				  cell.classList.add('pen'); cell.onclick = setPen; break;
		    case 'clave': ie.disabled = true; inputs(row, 'uidSAT', true).disabled = false;
				  cell.classList.add('clip'); cell.onclick = setClip; break;
		    case 'costo': inputs(row, 'costol', false); break;
		    case 'fecha': ie.disabled = true; break;
		    case 'proveedor': cell.colSpan = 2;
				      selects(k, cell, getSuppliers);
				      cell = row.insertCell();
				      k = 'uidPROV'; ie.name = k; break;
		}
		if (k.startsWith('prc')) { selects(k.replace('prc', 'u'), row.insertCell(), getUnits); inputs(row, k.replace('prc', 'precio'), false); }
		if (costos.has(k)) { ie.type = 'number'; }
		cell.appendChild( ie );
 		fields.add( k );
	    }

	    XHR.getJSON('/json/units.json')
			.then(a => a.forEach( u => UNITS.push(u) ))
			.then( () => XHR.getJSON('/json/header.json') )
			.then(a => a.forEach( addField ));

	})();

