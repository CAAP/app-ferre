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

	    editar.add = () => {
		if (!visible) { return; }
		switch(visible) {
		    case 'empleados': return editar.addEmployee();
			break;
		    default: break;
		};
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

	    function reassure(e) {
		const pid = e.target.parentElement.dataset.pid;
		if (window.confirm('Quieres eliminar esta persona?'))
		    ;
	    }

	    function zerop(e) {
		const pid = e.target.parentElement.dataset.pid;
		if ((e.target.dataset.pcode != '0') && window.confirm('Deseas resetear el pin?'))
		    editar.xget('pins', {pid: pid, pincode: 0});
	    }

	    function addRow(p) {
		const row = employees.insertRow();
		const pid = Number(p.id);
		row.dataset.pid = pid;
		// NOMBRE
		let n = inputE([['value', p.nombre], ['type', 'text'], ['size', 10], ['placeholder', 'Nombre'], ['name', 'empleado']]);
		row.insertCell().appendChild( n );
		//  PINCODE
		n = row.insertCell();
		n.appendChild( document.createTextNode(' ') );
		n.dataset.pcode = 0;
		n.onclick = zerop;
		// TRASH-OUT
		n = row.insertCell(); n.classList.add('trashout');
		n.appendChild( document.createTextNode(' ') );
		n.onclick = reassure;
	    }

	    editar.pins = function(pid, pcode) {
		PINS.set(pid, pcode);
		employees.querySelector('tr[data-pid="'+pid+'"]').querySelector('td[data-pcode]').dataset.pcode = pcode;
	    };

	    editar.addEmployee = function() {
		const chn = employees.children;
		addRow({id: 'A', nombre: ''});
		chn[chn.length].querySelector('input').focus();
	    };

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
	    const vars = ['nombre', 'ciudad']; // , 'rfc', 'email', 'tel', 'whats', 'contact', 'fecha'

	    function inputE( a ) {
		let ret = document.createElement('input');
		a.forEach( o => { ret[o[0]] = o[1] } );
		return ret;
	    }

	    function choices(s, b) {
		let opt = document.createElement('option');
		opt.value = s;
		opt.appendChild(document.createTextNode(s));
		opt.selected = b;
		return opt;
	    }

	    function addRow(p) {
		const row = employees.insertRow();
		// RAZON SOCIAL
		row.insertCell().appendChild( inputE([['type', 'text'], ['size', 15], ['value', p.nombre], ['name', 'nombre']]) );
	    }

	    XHR.getJSON('/json/proveedores.json').then( a => a.forEach( addRow ) );
	})();

