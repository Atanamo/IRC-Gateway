
//var createGateway = require('irc-gateway');
var createGateway = require('../src_js/server/index');

var config = require('./custom_config')

var gateway = createGateway(config);

gateway.start();


