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
//	    let takepic = document.createElement('button');

	    let row = tbody.insertRow();
	    row.insertCell().appendChild(video);
	    row.insertCell().appendChild(photo);

	    canvas.style.display = 'hidden';
	    document.body.appendChild(canvas);

	    navigator.mediaDevices.getUserMedia({ video: {facingMode: "environment" } })
	    .then(stream => {
		video.srcObject = stream;
		video.onloadedmetadata = e => {
		    height = width * video.videoHeight / video.videoWidth;
		    video.width = width;
		    video.height = height;
		    canvas.width = width;
		    canvas.height = height;
		}
	    }).catch( e => console.log );

/*	    video.addEventListener('canplay', e => {
		if (!streaming) {
		    height = width * video.videoHeight / videoWidth;
		    video.width = width;
		    video.height = height;
		    canvas.width = width;
		    canvas.height = height;
		    streaming = true;
		}
	    }, false); */

	    function clearphoto() {
		let context = canvas.getContext('2d');
		context.fillStyle = '#AAA';
		context.fillRect(0, 0, width, height);
		let data = canvas.toDataURL('image/png');
		photo.setAttribute('src', data);
	    }

	    function takepic() {
		let context = canvas.getContext('2d');
		context.drawImage(video, 0, 0, width, height);
		let data = canvas.toDataURL('image/jpeg');
	    }

	    pictic.start = () => video.play();

	    pictic.stop = () => video.pause();

	    // TICPIC

	    (function() {
		let diag = document.getElementById('dialogo-pictic');
		pictic.roll = () => { diag.showModal(); pictic.start(); };
		pictic.shutme = e => { pictic.stop(); diag.close(); };
	    })();
	};

