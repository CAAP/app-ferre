	    // FACTURAR

	    (function() {
		let diagR = document.getElementById( 'dialogo-rfc' );
		let diagF = document.getElementById( 'dialogo-factura' );
		let tabla = document.getElementById( 'tabla-rfc' );

		function makeDisplay( k ) {
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

		function displayRFC(e) {
		    let rfc = e.target;
		    if ((rfc.value.length>10) && (rfc.validity.valid))
			    XHR.getJSON('/ferre/rfc.lua?rfc=' + rfc.value)
			    .then( a => {
				if (a.length==1) {
				    let q = a[0];
				    for (let k in q) { fillVal(k, q[k]); }
				    ferre.factura();
				}
			    });
		}

		function correos() {
		    XHR.get('http://www.correosdemexico.gob.mx/lservicios/servicios/descarga.aspx')
			.then( data => console.log(data) );
		}

		// FIll-in the fields of 'tabla-rfc' inside 'dialogo-rfc'
		XHR.getJSON('/ferre/factura.lua')
		    .then( a => a.forEach( makeDisplay ) )
		    .then( () => {
//			['colonia', 'ciudad', 'estado'].forEach( x => { tabla.querySelector('input[name="'+x+'"').disabled = true; } );
			['ciudad', 'correo', 'calle'].forEach( x => { tabla.querySelector('input[name="'+x+'"').size = 25; } );
//			tabla.querySelector('input[name="cp"]').addEventListener('change', correos, false);
		    });

		diagR.querySelector('input[type=search]').addEventListener("keyup", displayRFC, false);

		ferre.rfc = () => diagR.showModal();

		ferre.factura = () => { diagR.close(); diagR.querySelector('input').value = ''; diagF.showModal(); };

		ferre.enviarF = () => { diagF.close(); ferre.print('facturar', tabla.querySelector('input[name=rfc]').value); clearVals(); };

	    })();






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


