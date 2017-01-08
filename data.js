	"use strict";

	var DATA = { VERSION: 1, DB: 'datos', clearTable: tb => { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } } };

	(function() {
	    function prc2txt(q) { // maybe improve SO not to do it for all prices XXX
		q.precios = {};
		for (let i=1; i<4; i++) {
		    let k = 'precio'+i;
		    if (q[k] > 0)
			q.precios[k] = q[k].toFixed(2) + ' / ' + q['u'+i];
		}
		return q;
	    }

	    let PRICE = {
		STORE: 'precios',
		INDEX: 'desc',
		update: o => {
		    if (o.desc && o.desc.startsWith('VV')) { return IDB.write2DB( PRICE ).delete( o.clave ); }
		    let os = IDB.write2DB( PRICE );
		    return os.get( o.clave ).then( q => {if (q) {return Object.assign(q, o);} else {return o;} } )
			.then( prc2txt )
			.then( os.put )
			.then( DATA.inplace );
		}
	    };

	    let PACK = {
		STORE: 'paquetes',
		INDEX: 'uid',
		update: o => {
		    let os = IDB.write2DB( PACK );
		    return os.get( o.clave ).then( q => {if (q) {return Object.assign(q, o);} else {return o;} } )
			.then( os.put )
			.then( DATA.inplace )
			.then( o => { if (o.desc.startsWith('VV')) {return os.delete( o.clave );} } );
		}
	    };

	    let FALT = {STORE: 'precios', INDEX: 'faltante'};

	    let PROV = {STORE: 'precios', INDEX: 'proveedor'};

	    let lvers;

	    let VERS =  {update: o => {localStorage.vers = o.vers; localStorage.week = o.week; lvers.textContent = ' | ' + o.week + 'V' + o.vers }};

	    let STORES = {PRICE:PRICE, PACK:PACK, FALT:FALT, PROV:PROV, VERS:VERS}; // COST:COST

	    DATA.STORES = STORES;

	    let updateMe = data => Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) );

	    DATA.onLoaded = esrc => {
		Object.keys(STORES).forEach(store => {STORES[store].CONN = DATA.CONN}); // XXX other method instead of Object.keys

		esrc.addEventListener('update', e => {
		    const data = JSON.parse(e.data);
		    const upd = data.find(o => {return o.store == 'VERS'});

//		    Promise.all( data.map( DATA.inplace ) ); XXX Need to address issue of already registered from admin et al.
		    if (localStorage.week && upd.week == localStorage.week && upd.prev == localStorage.vers) {
			console.log('Update event ongoing!');
			updateMe( data );
		    } else {
			console.log('Update mismatch error: ' + localStorage.week + '(' + upd.week + ') V' + localStorage.vers + '(V' + upd.vers + ')');
			XHR.getJSON('/ferre/updates.lua?oweek='+localStorage.week+'&overs='+localStorage.vers+'&nweek='+upd.week).then( updateMe );
		    }
		}, false);
	    };

	})();
