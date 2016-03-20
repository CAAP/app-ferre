	"use strict";

	var SQL = { DB: '' };

	(function () {

	    function xget( q, o ) { return XHR.get( 'cgi-bin/' + SQL.DB + '/db-' + q + '?' + asstr(o) ) }

	    function asstr( obj ) {
		let props = [];
		for (var prop in obj) { props.push( prop + '=' + obj[prop] ) }
		return props.join('&');
	    }

	    SQL.add = o => { return xget( 'add', o ) };

	    SQL.update = o => { return xget( 'update', o ) };

	    SQL.remove = o => { return xget( 'remove', o ) };

	})();

