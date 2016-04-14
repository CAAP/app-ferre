
	"use strict";

	var SQL = { DB: '' };

	(function () {

	    function asstr( obj ) {
		if (Array.isArray(obj))
		    return obj.join('&');
		let props = [];
		for (var prop in obj) { props.push( prop + '=' + obj[prop] ) }
		return props.join('&');
	    }

	    function xget( q, o ) { return XHR.get( SQL.DB + '/' + q + '.lua?' + asstr(o) ) }

	    function nget( q, o ) { return XHR.get( 'http://192.168.1.14:8081/' + q + '.lua?' + asstr(o) ) }

	    SQL.add = o => { return xget( 'add', o ) };

	    SQL.update = o => { return xget( 'update', o ) };

	    SQL.remove = o => { return xget( 'remove', o ) };

	    SQL.get = o => { return xget( 'get', o ) };

	    SQL.print = o => { return nget( 'print', o ) }; 

	})();

