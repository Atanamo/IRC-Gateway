
//var createGateway = require('irc-gateway');
var setupGateway = require('../src_js/server/index');

var config = require('./custom_config')

var gateway = setupGateway(config);

gateway.start();


