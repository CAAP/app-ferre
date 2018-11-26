	    // FACTURAR

	    (function (){
		let diag = document.getElementById( 'dialogo-rfc' );
		let tabla = document.getElementById( 'tabla-rfc' );
		let ancho = new Set(['ciudad', 'correo', 'calle']);
		const hoy = new Date().toLocaleDateString('es-MX');

		function makeDisplay( k ) {
		    let row = tabla.insertRow();
		    row.insertCell().appendChild( document.createTextNode(k.replace(/([A-Z])/g,' $1')) );
		    let ie = document.createElement('input');
		    ie.type = 'text'; ie.size = 12; ie.name = k; ie.disabled = true;
		    if (ancho.has(k)) { ie.size = 25; }
		    if (k == 'razonSocial') { ie.size = 40; }
		    row.insertCell().appendChild( ie );
		}

		function fillVal( k, v ) {
		    let ie = tabla.querySelector('input[name='+k+']');
		    if (ie) { ie.value = v; }
		}

		XHR.getJSON('/ferre/factura.lua').then( a => a.forEach( makeDisplay ) );

		caja.timbrar = function() {
		    let rfc = TICKET.bagRFC;
		    XHR.getJSON('/ferre/rfc.lua?rfc=' + rfc)
			.then( a => {
			    if (a.length==1) {
				let q = a[0];
				for (let k in q) { fillVal(k, q[k]); }
				diag.showModal();
			    }
			});
		};

	    })();


