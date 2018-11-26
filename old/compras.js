        "use strict";

	var compras = {};

	window.onload = function() {

	    (function() {
		const cpts = document.getElementById('tabla-conceptos');
		const ATTS = ['descripcion', 'valorUnitario'];

		function getAttributes( concepto ) {
		    let row = cpts.insertRow();
		    ATTS.forEach( att => row.insertCell().appendChild( document.createTextNode(concepto.getAttribute(att)) ) );
		}

		function procesar(dom) {
		    let emisor = dom.querySelector('Emisor').getAttribute('nombre');
		    cpts.insertRow().insertCell().appendChild( document.createTextNode(emisor) );
		    Array.from(dom.querySelector('Conceptos').children).forEach( getAttributes );
		}

	    compras.asxml = function(e) {
		let file = e.target.files[0];
		if (file.name.toLowerCase().endsWith('xml')) {
		    let parser = new DOMParser();
		    let reader = new FileReader();
		    reader.onloadend = e => procesar( parser.parseFromString(e.target.result, 'text/xml') );
		    reader.readAsText( file );
		}
	    };

	    })();

	    // SET HEADER
	    (function() {
	        let note = document.getElementById('notifications');
		let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
		function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
		note.appendChild( document.createTextNode( now(FORMAT) ) );
	    })();

	    // SET FOOTER
	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();



	}


