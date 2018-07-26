#
# Package main file
#

Config = require './config'


gatewayInstance = null


createGateway = (customConfig) ->
    # Set up config
    if customConfig?
        Config._overwriteDefaults(customConfig)
    else
        console.error('\nMissing configuration settings for IRC gateway!\n')

    # Get gateway instance
    unless gatewayInstance?
        Gateway = require './app'
        gatewayInstance = new Gateway()

    return gatewayInstance


module.exports = createGateway
