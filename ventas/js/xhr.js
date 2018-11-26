	"use strict";

	var XHR = {};

	(function() {

	function request(url, options) {
	    return new Promise((resolve, reject) => {
	        let xhr = new XMLHttpRequest;
	        xhr.onload = event => { if (event.target.status == 200) {resolve( event.target.response )} else {reject(event.target)} };
	        xhr.onerror = reject;

	        let defaultMethod = options.data ? "POST" : "GET";

	        if (options.mimeType)
	            xhr.overrideMimeType(params.options);

	        xhr.open(options.method || defaultMethod, url);

	        if (options.responseType)
	            xhr.responseType = options.responseType;

		// is it possible to use MERGE instead
	        for (let header of Object.keys(options.headers || {}))
	            xhr.setRequestHeader(header, options.headers[header]);

	        let data = options.data;
	        if (data && Object.getPrototypeOf(data).constructor.name == "Object") {
	            options.data = new FormData;
	            for (let key of Object.keys(data))
	                options.data.append(key, data[key]);
	        }

	        xhr.send(options.data);
	    });
	}

	XHR.post = function(url, data, headers) { return request(url, Object.assign({ responseType: 'text', data: data }, headers)).then( console.log('Successful POST!') ); }

	XHR.get = function(url) { return request(url, { responseType: 'text' }).then( console.log('Successful GET!') ); }

	XHR.getJSON = function(url) { return request(url, { responseType: 'text' }).then( JSON.parse ); }

	})();


