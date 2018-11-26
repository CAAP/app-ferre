        "use strict";

	var app = {};

	window.onload = function addFuns() {

	    (function() {
		const DEST = document.querySelector('input[name="dest"]');

		let body = { api_key: 'api-5BE260CC05B511E7B892F23C91C88F4E',
			sender: 'Ferreteria Aguilar <facturas@ferreteria.aguilar.mx>',
			to: ['<capagp@gmail.com>'],
			subject: 'Factura Electronica',
			text_body: '',
			html_body: '<h1>Envio automatizado de factura electronica.</h1>',
			custom_headers: [{header: 'Reply-To', value: '<ferreaguilar@yahoo.com.mx>'}]}

		app.sendmail = function() {
		    body.text_body = 'My first ever test!';
		    XHR.post('https://api.smtp2go.com/v3/email/send', JSON.stringify(body), {headers: {"Content-Type": 'application/json'}}).then(console.log, console.log);
		};
	    })();

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
