    let myname = document.getElementById("nombre");
    let flist = document.getElementById("filelist");
    let pick = document.getElementById("pickfiles");
    let enviar = document.getElementById("uploadfiles");
    let cmnts = document.getElementById("comentarios");
    let console = document.getElementById('console');

    function addName( p ) {
	let opt = document.createElement("option");
	opt.value = p.id;
	opt.appendChild(document.createTextNode(p.nombre)); myname.appendChild(opt);
    }

    var NOMBRES = ['', ];
    XHR.getJSON("json/nombres.json").then( a => a.forEach( p => { NOMBRES[p.id] = p.nombre; addName(p); } ) );

    let uploader = new plupload.Uploader({ 
	runtimes: "html5, html4",
	browse_button: "pickfiles",
	container: "container",
	url: "uploadCFDI.lua",
	multipart: true,
	multipart_params: {},

	filters : {
	    mime_types: [
		{title : "xml", extensions: "xml"},
		{title: "XML", extensions: "XML"}
	    ]
	},

	init: {
	    PostInit: function() {
		flist.innerHTML = "";
		enviar.onclick = function() {
		    uploader.start();
		    return false;
		};
	    },
	    FilesAdded: function(up, files) {
		plupload.each(files, function(file) {
		    flist.innerHTML += '<div id="' + file.id + '">' + file.name + ' (' + plupload.formatSize(file.size) + ') <b></b></div>';
		});
	    },
	    FileUploaded: function(up, file) {
		setTimeout(function() {
		    document.getElementById(file.id).remove();
		    console.appendChild(document.createTextNode("\nArchivo enviado: " + file.name));
		}, 2500);
	    },
	    BeforeUpload: function(up, files) {
		up.settings.multipart_params.nombre = myname.value;
		up.settings.multipart_params.comentarios = cmnts.value;

		setTimeout(function() {
		    myname.value = 1;
		    cmnts.value = '';
		}, 500);
	    },
	    UploadProgress: function(up, file) {
		document.getElementById(file.id).getElementsByTagName('b')[0].innerHTML = '<span>' + file.percent + '%</span>';
	    },
	    Error: function(up, err) {
		console.appendChild(document.createTextNode("\nError #" + err.code + ": " + err.message));
		setTimeout(() => flist.lastElementChild.remove(), 500);
	    }
	}
    });
    uploader.init();

