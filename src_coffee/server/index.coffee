#
# Package main file
#

config = require './config'


gatewayInstance = null

setupGateway = (customConfig) ->
    # Set up config
    if config._overwriteDefaults?
        if customConfig?
            config._overwriteDefaults(customConfig)
            config._overwriteDefaults = null
        else
            console.error('\nMissing configuration settings for IRC gateway!\n')
    else if customConfig?
        console.warn('\nIRC gateway already created, cannot change its config!\n')

    # Get gateway instance
    unless gatewayInstance?
        Gateway = require './app'  # Lazy load
        gatewayInstance = new Gateway()

    return gatewayInstance


module.exports = setupGateway
