	"use strict";

	var PEOPLE = {};

	// PEOPLE
	(function() {
	    PEOPLE.id = [''];
	    XHR.getJSON( '/ferre/empleados.lua' ).then( a => {
		a.forEach( o => { PEOPLE.id[o.id] = o.nombre; } );
	    });
	})();

