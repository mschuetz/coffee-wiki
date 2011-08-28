var coffee = require('coffee-script');
var fs = require('fs');

fs.readFile('server.coffee', 'utf-8', function(err, code) {
	if (err) {
		throw err;
	}
	coffee.run(code, {filename: 'server.coffee'});
});