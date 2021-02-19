	var UTILS = {
	    asnum: s => { let n = Number(s); return Number.isNaN(n) ? s : n; },

	    redondeo: x => { return 50 * Math.floor( (x + 25) / 50 ) },

	    mapObj: (o, f) => Object.keys(o).map( f ),

	    forObj: (o, f) => Object.keys(o).forEach( f ),

	    getStrPpties: (a, o, m) => {
		let ret = {}
		Object.keys(o).forEach(k => {
		    if (m.has(k))
			ret[k] = o[k]
		});
		return Object.assign(ret, a);
	    },

	    ppties: o => UTILS.mapObj(o, k => { return (k + "=" + o[k]) }).join('&'),

	    encPpties: o => UTILS.mapObj(o, k => { return (k + '=' + encodeURIComponent(o[k])); } ).join('&'),

	    asstr: o => (Array.isArray(o) ? o.join('&') : UTILS.ppties(o)),

	    promiseAll: (data, f) => Promise.all( data.map( f ) ),

	    clearTable: tb => { while (tb.firstChild) { tb.removeChild( tb.firstChild ); } }
	};



