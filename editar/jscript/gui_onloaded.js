	// HEADER
	(function() {
	    let FORMAT = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
	    function now(fmt) { return new Date().toLocaleDateString('es-MX', fmt) }
	    document.getElementById('notifications').innerHTML = now(FORMAT);
	    document.getElementById("eventos").innerHTML = 'Loading ...'
	    document.getElementById('copyright').innerHTML = 'versi&oacute;n ' + 1.0 + ' | cArLoS&trade; &copy;&reg;';
	})();

	// EDITAR
	(function() {
	    const formas = { empleados: document.getElementById("empleados"),
			     proveedores: document.getElementById("proveedores"),
			     clientes: document.getElementById("clientes") };
	    let visible = false;

	    editar.origin = document.location.origin+':5040/';
	    editar.show = a => {
		if (!visible) {
		    formas[a].style.visibility = 'visible';
		    visible = a;
		    return true;
		}
		if (visible == a)
		    return true;
		else {
		    formas[a].style.visibility = 'visible';
		    formas[visible].style.visibility = 'collapse';
		    visible = a;
		}
	    };
	})();

	// EMPLEADOS
	(function() {
	    var PINS   = new Map();
	    var NAMES  = new Map();

	    const employees = document.getElementById("tabla-empleados");

	    function inputE( a ) {
		let ret = document.createElement('input');
		a.forEach( o => { ret[o[0]] = o[1] } );
		return ret;
	    }

//  if (PINS.get(pid) == 0) { n.classList.add('dots'); } XXX

	    function addRow(p) {
		const row = employees.insertRow();
		// NOMBRE
		row.insertCell().appendChild( document.createTextNode(p.nombre) );
		//  PINCODE
		let n = row.insertCell();
		n.appendChild( document.createTextNode(' ') );
		n = row.insertCell(); n.classList.add('backs');
		n.appendChild( document.createTextNode(' ') );
	    }

	    XHR.getJSON('/json/people.json').then(
		a => a.forEach( p => {
		    const pid = Number(p.id);
		    PINS.set(pid, 0); // initialize to 0
		    NAMES.set(pid, p.nombre.toUpperCase());
		    addRow(p);
		}));
	})();

	// PROVEEDORES
	(function() {
	    const employees = document.getElementById("tabla-proveedores");
	    const vars = ['nombre', 'ciudad', 'rfc', 'email', 'tel', 'whats', 'contact', 'fecha'];

	    function inputE( a ) {
		let ret = document.createElement('input');
		a.forEach( o => { ret[o[0]] = o[1] } );
		return ret;
	    }

	    function addRow(p) {
		const row = employees.insertRow();
		vars.forEach(v => row.insertCell().appendChild( document.createTextNode(p[v] || '') ));
	    }

	    XHR.getJSON('/json/proveedores.json').then( a => a.forEach( addRow ) );
	})();

