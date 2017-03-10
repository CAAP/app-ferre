        "use strict";

	var app = {};

	window.onload = function addFuns() {

	    // HEADER

	    (function() {
	        const note = document.getElementById('notifications');
		const FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    	const now = new Date().toLocaleDateString('es-MX', FORMAT);

		note.appendChild( document.createTextNode( now ) );
	    })();

	    // FOOTER

	    (function() { document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;'; })();

	};
