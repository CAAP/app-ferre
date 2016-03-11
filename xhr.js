	"use strict";

	var XHR = {};

	(function() {

	function request(url, options) {
	    return new Promise((resolve, reject) => {
	        let xhr = new XMLHttpRequest;
	        xhr.onload = event => resolve( event.target.response );
	        xhr.onerror = reject;

	        let defaultMethod = options.data ? "POST" : "GET";

	        if (options.mimeType)
	            xhr.overrideMimeType(params.options);

	        xhr.open(options.method || defaultMethod, url);

	        if (options.responseType)
	            xhr.responseType = options.responseType;

	        for (let header of Object.keys(options.headers || {}))
	            xhr.setRequestHeader(header, options.headers[header]);

	        let data = options.data;
	        if (data && Object.getPrototypeOf(data).constructor.name == "Object") {
	            options.data = new FormData;
	            for (let key of Object.keys(data))
	                options.data.append(data[key]);
	        }

	        xhr.send(options.data);
	    });
	}

	XHR.post = function(url, data) { return request(url, { responseType: 'text', data: data }).then( console.log('Successful POST!') ); }

	XHR.getJSON = function(url) { return request(url, { responseType: 'text' }).then( JSON.parse ); }
	})();


