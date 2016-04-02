
	"use strict";

	var SQL = { DB: '' };

	(function () {

	    function asstr( obj ) {
		let props = [];
		for (var prop in obj) { props.push( prop + '=' + obj[prop] ) }
		return props.join('&');
	    }

	    function xget( q, o ) { return XHR.get( SQL.DB + '/' + q + '.lua?' + asstr(o) ) }

	    SQL.add = o => { return xget( 'add', o ) };

	    SQL.update = o => { return xget( 'update', o ) };

	    SQL.remove = o => { return xget( 'remove', o ) };

	    SQL.get = o => { return xget( 'get', o ) };

	    SQL.print = o => { return xget( 'print', o ) }; 

	})();

