	    // PAGAR

	    (function() {
		const BRUTO = 1.16;
		const IVA = 7.25;
		const tiva = document.getElementById( TICKET.tivaID );
		const tbruto = document.getElementById( TICKET.tbrutoID );
		const ttotal = document.getElementById( TICKET.ttotalID );

		function tocents(x) { return (x / 100).toFixed(2); };

		TICKET.total = function(amount) {
		    tiva.textContent = tocents( amount / IVA );
		    tbruto.textContent = tocents( amount / BRUTO );
		    ttotal.textContent = tocents( amount );
		};

		const paga = document.getElementById( "dialogo-pagar" );
		const mytotal = paga.querySelector('input[name="cuenta"]');
		const mydebt =  paga.querySelector('output');

		caja.validar = function(e) {
		    if ( parseFloat(mydebt.value) >= 0 )
			paga.close();
		};

//		PAGADO can be added to ticket, it's a map
		caja.pagar = function() {
		    mytotal.value = ttotal.textContent;
		    paga.showModal();
		};
	    })();


