
	"use strict";

	var SQL = { DB: '' };

	(function () {

	    const asstr = UTILS.asstr;

	    function xget( q, o ) { return XHR.get( SQL.DB + '/' + q + '.lua?' + asstr(o) ) }

//	    SQL.add = o => { return xget( 'add', o ) };

	    SQL.update = o => { return xget( 'update', o ) };

	    SQL.pesos = o => { return xget( 'pesos', o ) };

	    SQL.get = o => { return xget( 'get', o ) };

	    SQL.print = o => { return xget( 'print', o ) }; 

	    SQL.query = o => { return xget( 'query', o) };

	})();

