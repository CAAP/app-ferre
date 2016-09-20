	"use strict";

	    (function() {
		let NUMS = {};
		NUMS.C = {0: '', 1: 'CIENTO ', 2: 'DOSCIENTOS ', 3: 'TRESCIENTOS ', 4: 'CUATROCIENTOS ', 5: 'QUINIENTOS ', 6: 'SEISCIENTOS ', 7: 'SETECIENTOS ', 8: 'OCHOCIENTOS ', 9: 'NOVECIENTOS '};
		NUMS.D = {0: '', 10: 'DIEZ ', 11: 'ONCE ', 12: 'DOCE ', 13: 'TRECE ', 14: 'CATORCE ', 15: 'QUINCE ', 16: 'DIECISEIS ', 17: 'DIECISIETE ', 18: 'DIECIOCHO ', 19: 'DIECINUEVE ', 3: 'TREINTA ', 4: 'CUARENTA ', 5: 'CINCUENTA ', 6: 'SESENTA ', 7: 'SETENTA ', 8: 'OCHENTA ', 9: 'NOVENTA '}
		NUMS.I = {0: '', 1: 'UNO ', 2: 'DOS ', 3: 'TRES ', 4: 'CUATRO ', 5: 'CINCO ', 6: 'SEIS ', 7: 'SIETE ', 8: 'OCHO ', 9: 'NUEVE '};
		NUMS.M = {3: 'MIL ', 6: 'MILLON '};

		const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijkmnopqrstuvwxyz";
		let TKT = '';

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

		TICKET.enpesos = function enpesos(z) {
		    let y = Math.floor( Math.log10(z) );
//		    let z = x.toFixed(2);
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

	    })();

