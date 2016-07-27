	"use strict";

	var PEOPLE = {};

	// PEOPLE
	(function() {
	    PEOPLE.id = [''];

	    PEOPLE.nombre = {};

	    PEOPLE.tabs = new Map();

	    PEOPLE.load = tb => {
		let row = tb.insertRow();
		XHR.getJSON( '/ferre/empleados.lua' )
		    .then( a => { a.forEach( p => {PEOPLE.id[p.id] = p.nombre; PEOPLE.nombre[p.nombre] = p.id; row.insertCell().appendChild( document.createTextNode( p.nombre ) );} ) } )
		    .then(() => { row.firstChild.classList.toggle('activo'); tb.dataset.id=1;} );
	    };
	})();

