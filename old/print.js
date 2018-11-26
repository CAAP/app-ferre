// PRINTING //

	    let printing = (function() {
		let NUMS = {};
		NUMS.C = {0: '', 1: 'CIENTO ', 2: 'DOSCIENTOS ', 3: 'TRESCIENTOS ', 4: 'CUATROCIENTOS ', 5: 'QUINIENTOS ', 6: 'SEISCIENTOS ', 7: 'SETECIENTOS ', 8: 'OCHOCIENTOS ', 9: 'NOVECIENTOS '};
		NUMS.D = {0: '', 10: 'DIEZ ', 11: 'ONCE ', 12: 'DOCE ', 13: 'TRECE ', 14: 'CATORCE ', 15: 'QUINCE ', 16: 'DIECISEIS ', 17: 'DIECISIETE ', 18: 'DIECIOCHO ', 19: 'DIECINUEVE ', 3: 'TREINTA ', 4: 'CUARENTA ', 5: 'CINCUENTA ', 6: 'SESENTA ', 7: 'SETENTA ', 8: 'OCHENTA ', 9: 'NOVENTA '}
		NUMS.I = {0: '', 1: 'UNO ', 2: 'DOS ', 3: 'TRES ', 4: 'CUATRO ', 5: 'CINCO ', 6: 'SEIS ', 7: 'SIETE ', 8: 'OCHO ', 9: 'NUEVE '};
		NUMS.M = {3: 'MIL ', 6: 'MILLON '};

		let HEADER = ['<html><head><link rel="stylesheet" href="ticket.css" media="print"></head><body><table><thead>', '', '<tr><th colspan=4>FERRETERIA AGUILAR</th></tr><tr><th colspan=4>FERRETERIA Y REFACCIONES EN GENERAL</th></tr><tr><th colspan=4>Benito Juarez No 1C  Ocotlan, Oaxaca</th></tr><tr><th colspan=4>', '', '&emsp; Tel. 57-10076</th></tr><tr class="doble"><th>CNT</th><th>DSC</th><th>PRECIO</th><th>TOTAL</th></tr></thead><tbody>']
		const STRLEN = 5;
		const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz";
		let TKT = '';

		ferre.printDialog = function printDialog(args) { HEADER[1] = (args=='ticket' ? '' : '<tr><th colspan=4>PRESUPUESTO</th></tr>'); setPrint(); };

		function topesos(x) { return (x / 100).toLocaleString('es-MX', {style:'currency', currency:'MXN'}); };

		function decenas(d,u) {
		    let ret = '';
		    switch(d) {
			case '1': return NUMS.D[d+u];
			case '2': ret += (u=='0' ? 'VEINTE ': 'VEINTI'); break;
			default: ret += NUMS.D[d] + (u == '0' ? '' : 'Y ');
		    }
		    return ret + NUMS.I[u];
		};

		function enpesos(x) {
		    let y = Math.floor( Math.log10(x) );
		    let z = x.toFixed(2);
		    let ret = '';
		    for (let i = 0; i<=y; i++) {
			let j = z[i];
			let k = y-i;
			switch(k) {
			    case 5: case 2: ret += NUMS.C[j]; break;
			    case 4: case 1: ret += decenas(j, z[++i]); break;
			    case 3: case 6: ret += ((j=='1' ? 'UN ' : NUMS.I[j]) + NUMS.M[k]); break;
			    case 0: ret += NUMS.I[j];
			}
		    }
		    ret += 'PESO(S) ' + z.substr(y+2) + '/100 M.N.'
		    return ret;
		}

		function header() {
		    HEADER[3] = new Date().toLocaleString();
		    let ret = '';
		    HEADER.map( x => ret += x); //function(x) { ret += x; } );
		    return ret;
		};

		function newiframe() {
		    return new Promise( (resolve, reject) => {
			let iframe = document.createElement('iframe');
			iframe.style.visibility = "hidden";
			iframe.width = 400;
			myticket.appendChild( iframe );
			iframe.onload = resolve(iframe.contentWindow);
		    });
		}

		function printTicket( q ) {
		    let nombre = q.nombre, numero = randString();
		    TKT += '<tr><th colspan=2>'+nombre+'</th><th colspan=2 align="left">#'+numero+'</th></tr>';
		    TKT += '<tr><th colspan=4 align="center">GRACIAS POR SU COMPRA</th></tr></tfoot></tbody></table></body></html>'
		    return newiframe()
			.then( win => { let doc = win.document; doc.open(); doc.write(TKT); doc.close(); return win} )
			.then( win => win.print() )
			.then( () => myticket.removeChild(myticket.lastChild) );
		};

		function setPrint() {
		    let a = ['qty', 'rea'];
		    TKT = header();
		    let total = 0;
		    IDB.readDB( TICKET ).openCursor( cursor => {
			if (cursor) {
			    let q = cursor.value;
			    total += q.totalCents;
			    TKT += '<tr><td colspan=4>'+q.desc+'&emsp;'+q['u'+q.precio[6]]+'</td></tr><tr>';
			    a.map( function(k) { TKT += '<td align="center">'+ q[k] +'</td>'; } );
			    TKT += '<td class="pesos">'+q[q.precio].toFixed(2)+'</td><td class="pesos">'+tocents(q.totalCents)+'</td></tr>';
			    cursor.continue();
			}  else {
			    TKT += '<tfoot><tr><th colspan=4 class="total">Total de su compra: '+topesos(total)+'</th></tr>'
			    TKT += '<tr><th colspan=4>'+enpesos(total/100)+'</th></tr>'
			    persona.showModal();
			}
		    });
		};

		return function printing(e) {
		    let k = e.key || ((e.which > 90) ? e.which-96 : e.which-48);
		    persona.close(k);
		    e.target.textContent = '';
		    return IDB.readDB( PEOPLE ).get( k ).then( printTicket );
		}

	    })();


