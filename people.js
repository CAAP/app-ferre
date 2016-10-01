	"use strict";

	var PEOPLE = {};

	// PEOPLE
	(function() {
	    PEOPLE.id = [''];

	    PEOPLE.nombre = {};

	    PEOPLE.tabs = new Map();

	    PEOPLE.load = () => XHR.getJSON( '/ferre/empleados.lua' ).then( a => { a.forEach( p => { PEOPLE.id[p.id] = p.nombre; PEOPLE.nombre[p.nombre] = Number(p.id); } ); return a; } );

	})();



/*
	    // PEOPLE - Scheduling support
	    (function() {
		const slc = document.getElementById('personas');
		const tag = document.getElementById('tag');
		const schedule = document.getElementById('dialogo-schedule');
		const action = schedule.querySelector('button[name=action]');

		let msg_tag = pid => {
			tag.textContent = PEOPLE.horarios.get(pid);
			if ((tag.textContent[0] == 'E') ^ (tag.classList.contains('entrada')))
			    tag.classList.toggle('entrada');
		}

		caja.marcar = e => {
		    const a = e.target.textContent;
		    XHR.get( document.location.origin + ':8081/marcar?id_tag=h&tag=' + a + '&pid=' + slc.value )
			.then( () => schedule.close() );
		};

		caja.showD = () => {
		    action.textContent = (tag.textContent[0] == 'E') ? 'SALIDA' : 'ENTRADA';
		    schedule.showModal();
		};

		caja.tab = () => {
		    const pid = Number(slc.value);
		    if (pid == 1) { tag.textContent = ''; return; }
		    if (PEOPLE.horarios.has(pid)) { msg_tag( pid ); }
		    else { tag.textContent = ''; action.textContent = 'ENTRADA'; schedule.showModal(); }
		};

		PEOPLE.load().then( a => a.forEach( p => { let opt = document.createElement('option'); opt.value = p.id; opt.appendChild(document.createTextNode(p.nombre)); slc.appendChild(opt); } ) );

		PEOPLE.horarios = new Map();

	    })();
*/


