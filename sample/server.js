
//const gateway = require('irc-gateway');
const gateway = require('../dist/server/index');

const config = require('./custom_config');

const gatewayApp = gateway.setup(config, gateway.DefaultDatasource);

gatewayApp.start();

// To stop the gateway:
//gatewayApp.stop();

