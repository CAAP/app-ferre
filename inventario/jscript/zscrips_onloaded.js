    let myname = document.getElementById("nombre");
    let myreg = document.getElementById("registro");
    let enviar = document.getElementById("uploadfiles");
    let cmnts = document.getElementById("comentarios");
    let console = document.getElementById('console');

    function addName( p ) {
	let opt = document.createElement("option");
	opt.value = p.id;
	opt.appendChild(document.createTextNode(p.nombre)); myname.appendChild(opt);
    }

    let KEYS = new Set(["Backspace", "Delete", "Clear"]);
    function registre( e ) {
	let txt = e.target.value;
	if(txt.length == 6) {
	    txt += ' / ';
	    e.target.value = txt;
	}
	if( KEYS.has(e.key) && txt.length == 9 ) {
	    txt = txt.substring(0, 6);
	    e.target.value = txt;
	}
    }

    myreg.addEventListener('keydown', registre);

    var NOMBRES = ['', ];
    XHR.getJSON("json/nombres.json").then( a => a.forEach( p => { NOMBRES[p.id] = p.nombre; addName(p); } ) );

    let uploader = new plupload.Uploader({ 
	runtimes: "html5, html4",
	container: "container",
	url: "uploadVideo.lua",
	multipart: true,
	multipart_params: {},

	init: {
	    PostInit: function() {
		enviar.onclick = function() {
		    uploader.start();
		    return false;
		};
	    },
	    BeforeUpload: function(up, files) {
		up.settings.multipart_params.registro = myreg.value;
		up.settings.multipart_params.nombre = myname.value;
		up.settings.multipart_params.comentarios = cmnts.value;

		setTimeout(function() {
		    myreg.value = '';
		    myname.value = 1;
		    cmnts.value = '';
		}, 500);
	    },
	    Error: function(up, err) {
		console.appendChild(document.createTextNode("\nError #" + err.code + ": " + err.message));
	    }
	}
    });
    uploader.init();

