        "use strict";

	var pictic = {};

	window.onload = function() {
	    let tbody = document.getElementById('pic-body');

	    let width = 320;
	    let height = 0;
	    let streaming = false;

	    let video = document.createElement('video');
	    let canvas = document.createElement('canvas');
	    let photo = document.createElement('img');

	    video.classList.add('snapshot');

	    let row = tbody.insertRow();
	    row.insertCell().appendChild(video);
	    row.insertCell().appendChild(photo);

	    function clearphoto() {
		let context = canvas.getContext('2d');
		context.fillStyle = '#AAA';
		context.fillRect(0, 0, width, height);
		let data = canvas.toDataURL('image/png');
		photo.src = data;
	    }

	    function takepic() {
		let context = canvas.getContext('2d');
		context.drawImage(video, 0, 0, width, height);
		let data = canvas.toDataURL('image/jpeg');
		photo.src = data;
	    }

	    video.addEventListener('click', takepic, false);

	    function getStream(args) {
		return navigator.mediaDevices.getUserMedia(args)
		.then(stream => {
		    video.srcObject = stream;
		    video.onloadedmetadata = e => {
			height = width * video.videoHeight / video.videoWidth;
			video.width = width;
			video.height = height;
			canvas.width = width;
			canvas.height = height;
			clearphoto();
		    };
		    return stream;
		}).catch( e => console.log );
	    }

	    // INTIALIZATION

	    (function() {
		let dvcs = [];
		let vstream = null;
		let cnt = 0;

		navigator.mediaDevices.enumerateDevices().then( ds => ds.filter( d => d.kind.startsWith('video') ).forEach( d => dvcs.push(d) ) );

		getStream({video: true}).then( stream => { vstream = stream; } );

		pictic.flip = () => {
		    video.pause();
		    cnt = (1+cnt) % dvcs.length;
		    let id = dvcs[cnt].deviceId;
		    vstream.getTracks().forEach( track => track.stop() );
		    return getStream({audio: false, video: {deviceId: {exact: id}}}).then( stream => { vstream = stream; } ).then( pictic.start );
		};

	    })();

	    pictic.start = () => video.play();

	    pictic.stop = () => video.pause();

	    // TICPIC

	    (function() {
		let diag = document.getElementById('dialogo-pictic');
		pictic.roll = () => { diag.showModal(); pictic.start(); };
		pictic.shutme = e => { pictic.stop(); diag.close(); };
	    })();
	};

