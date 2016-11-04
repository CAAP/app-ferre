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
		    if (o.desc && o.desc.startsWith('VV')) { return os.delete( o.clave ); }
		    let os = IDB.write2DB( PRICE );
		    return os.get( o.clave ).then( q => {if (q) {return Object.assign(q, o);} else {return o;} } )
			.then( prc2txt )
			.then( os.put ) // XXX Join with last check i.e., if statement: put or delete, not both
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
/*	
	    let COST = {
		STORE: 'proveedores',
		INDEX: 'proveedor',
 		update: o => {
		    let os = IDB.write2DB( DATA.COSTO );
		    return os.get( o.clave ).then( q => {if (q) {return Object.assign(q, o);} else {return o;} } )
			.then( os.put )
			.then( DATA.inplace );
		}
	    };
*/
	    let FALT = {STORE: 'precios', INDEX: 'falt-prov-desc'};

	    let VERS =  {update: o => {localStorage.vers = o.vers; localStorage.week = o.week;}};

	    let STORES = {PRICE:PRICE, PACK:PACK, FALT:FALT, VERS:VERS}; // COST:COST

	    DATA.STORES = STORES;

	    DATA.onLoaded = esrc => {
		Object.keys(STORES).forEach(store => {STORES[store].CONN = DATA.CONN});
		esrc.addEventListener('update', e => {
		    const data = JSON.parse(e.data);
		    const upd = data.find(o => {return o.store == 'VERS'});
		    if (localStorage.week && upd.week < localStorage.week && upd.vers <= localStorage.vers) {console.log('Update already registered!'); return;}
		    console.log('Update event ongoing!');
		    Promise.all( data.map(q => {const store = q.store; delete q.store; return STORES[store].update(q);}) );
		}, false);
/*		if (localStorage.week && localStorage.vers)
		    XHR.get('/ferre/updates.lua?week='+localStorage.week+'&vers='+localStorage.vers);
		else
		    alert('No update-record found!'); */
	    };

	})();
