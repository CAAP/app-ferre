        "use strict";

	var app = {};

	window.onload = function() {
	    const DBs = [ DATA ];

	    app.reloadDB = function reloadDB() { return IDB.clearDB(DATA).then( () => IDB.populateDB( DATA ) ); };

	    // SQL

	    SQL.DB = document.location.origin + ':8081';

	    // BROWSE

	    BROWSE.tab = document.getElementById('resultados');
	    BROWSE.lis = document.getElementById('tabla-resultados');

            BROWSE.adapt = a => {a.precios = new Map(); return a};

	    BROWSE.DBget = s => IDB.readDB( DATA ).get( s );

	    BROWSE.DBindex = (a, b, f) => IDB.readDB( DATA ).index( a, b, f );

	    app.startSearch = BROWSE.startSearch;

	    app.keyPressed = BROWSE.keyPressed;

	    app.scroll = BROWSE.scroll;

	    app.cerrar = e => e.target.closest('dialog').close();

	    // TICKET -- DIALOG

	    (function() {
		let diagI = document.getElementById('dialogo-item');
		let inObs = diagI.querySelector('input[list=obs]');
		let lsObs = diagI.querySelector('#obs');
		let clave = -1;

		function asnum(s) { let n = Number(s); return Number.isNaN(n) ? s : n; }

		function choice(s) { let opt = document.createElement('option'); opt.value = s; lsObs.appendChild( opt ); }

		function clearTable(tb) { inObs.value = ''; while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }; //recycle?

		app.menu = e => {
		    clave = asnum(e.target.parentElement.dataset.clave);
		    IDB.readDB( DATA ).get( clave ).then(p => {if (p) { clearTable(lsObs); if (p.obs) { p.obs.forEach( choice ) }}}).then( () => diagI.showModal());
		};

		app.faltante = function() {
		    if (window.confirm('Enviar reporte de faltante?'))
			SQL.update({clave: clave, faltante: 1, obs: encodeURIComponent(inObs.value), tbname: 'faltantes', vwname: 'faltantes', id_tag: 'u'})
			    .then( () => diagI.close() );

		};
	    })();

	    // LOAD DBs
 	    if (IDB.indexedDB) { DBs.forEach( IDB.loadDB ); } else { alert("IDBIndexed not available."); }

	    // HEADER
	    (function() {
	        const note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 2.0 + ' | cArLoS&trade; &copy;&reg;' })();

	// SERVER-SIDE EVENT SOURCE
		(function() {
		    let esource = new EventSource(document.location.origin + ":8080");
		    esource.addEventListener("update", function(e) {
			console.log("update event received.");
			DATA.update( JSON.parse(e.data) );
		    }, false);
		    esource.addEventListener("faltante", function(e) {
			console.log("faltante event received.");
			DATA.update( JSON.parse(e.data) )
			    .then( () => { let r = document.body.querySelector('tr[data-clave="'+JSON.parse(e.data)[0].clave+'"]'); if (r) { r.querySelector('.desc').classList.add('faltante'); } } );
		    }, false);
		})();

	};

