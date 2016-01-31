

	    var printItem = function printItem(row, q) {
		var a = ['qty', 'desc', 'precio', 'rea', 'total'];
		a.map( function(x) { row.insertCell().appendChild( document.createTextNode(x) ); } )
	    };

	    ferre.printTICKET = function printTICKET(sURL) {
		var iframe = document.createElement('iframe');
		myticket.appendChild(iframe);
		var doc = iframe.contentWindow.document;
		var tbl = doc.createElement('table');
		doc.body.appendChild( tbl );
		var tb = doc.createElement('tbody');
		tbl.appendChild( tb );
		var total = 0;
		readDB( TICKET ).openCursor().onsuccess = function(e) {
		    var cursor = e.target.result;
		    if (cursor) {
			total += cursor.value.totalCents;
			printItem( tb.insertRow(), cursor.value );
			cursor.continue();
		    } //else { ttotal.textContent = tocents( total ); }
		};
	    };


