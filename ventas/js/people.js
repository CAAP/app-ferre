	"use strict";

	var PEOPLE = {};

	// PEOPLE
	(function() {
	    PEOPLE.id = [''];

	    PEOPLE.nombre = {};

	    PEOPLE.tabs = new Map();

	    PEOPLE.load = () => XHR.getJSON( '/app/empleados.lua' ).then( a => { a.forEach( p => { PEOPLE.id[p.id] = p.nombre; PEOPLE.nombre[p.nombre] = Number(p.id); } ); return a; } );

	})();

