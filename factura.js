


	    (function (){
		let diag = document.getElementById( 'dialogo-rfc' );
		let tabla = document.getElementById( 'tabla-rfc' );
		let ancho = new Set(['ciudad', 'correo', 'calle']);

		function makeTable( k ) {
		    let row = tabla.insertRow();
		    row.insertCell().appendChild( document.createTextNode(k.replace(/([A-Z])/g,' $1')) );
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 12; ie.name = k;
		    if (k == 'cp') { ie.type = 'search'; ie.placeholder = '00000'; ie.pattern = '\d+'; }
		    if (k == 'razonSocial') { ie.size = 40; }
		    if (k == 'rfc') { ie.type = 'search'; ie.placeholder = 'XAXX010101000'; ie.pattern = '^\w{3,4}\d{6}\w{3}$'; }
		    row.insertCell().appendChild( ie );
		}

		function fillVal( k, v ) {
		    let ie = tabla.querySelector('input[name='+k+']');
		    if (ie) { ie.value = v; }
		}

		function clearVals() { Array.from(tabla.querySelectorAll('input')).forEach( item => { item.value = ''; } ); }

		function toggle() { Array from(tabla.querySelectorAll('input')).forEach(ie => { ie.disabled = !ie.disabled; }); }


		// FIll-in the fields of 'tabla-rfc' inside 'dialogo-rfc'
		XHR.getJSON('/ferre/factura.lua')
		    .then( a => a.forEach( makeTable ) )
		    .then( () => {
//			['colonia', 'ciudad', 'estado'].forEach( x => { tabla.querySelector('input[name="'+x+'"').disabled = true; } );
			['ciudad', 'correo', 'calle'].forEach( x => { tabla.querySelector('input[name="'+x+'"').size = 25; } );
//			tabla.querySelector('input[name="cp"]').addEventListener('change', correos, false);
		    });

		diagR.querySelector('input').addEventListener("keyup", displayRFC, false);


