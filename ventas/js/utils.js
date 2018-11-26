	"use strict";

	var UTILS = {

	    asnum: s => { let n = Number(s); return Number.isNaN(n) ? s : n; }

	    mapObj: (o, f) => Object.keys(o).map( f ),

	    forObj: (o, f) => Object.keys(o).forEach( f ),

	    ppties: o => UTILS.mapObj(o, k => { return (k + "=" + o[k]) }).join('&'),

	    asstr: o => (Array.isArray(o) ? o.join('&') : UTILS.ppties(o)),

	    promiseAll: (data, f) => Promise.all( data.map( f ) ),

	    clearTable: tb => { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }
	};
