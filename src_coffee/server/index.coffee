##
## Package main file
##

# Include app modules for setup
config = require './config'
loader = require './databaseloader'

# Include database classes
DefaultDatabase = require './database.default'

# Setup mechanism
#
gatewayInstance = null

setupGateway = (customConfig, customDatabaseClass) ->
    # Set up config
    if config._overwriteDefaults?
        if customConfig?
            config._overwriteDefaults(customConfig)
            config._overwriteDefaults = null
        else
            console.error('\nMissing configuration settings for IRC gateway!\n')
    else if customConfig?
        console.warn('\nIRC gateway already created, cannot change its config!\n')

    # Set up database class
    # TODO: Check for instanceof interface class
    if typeof(customDatabaseClass) is 'function'
        loader.setClass(customDatabaseClass)
    else
        console.error('\nGiven object is no class, it cannot be used as database interface for the IRC gateway!\n')

    # Get gateway instance
    unless gatewayInstance?
        Gateway = require('./app')  # Lazy load, so injected config and database will be used
        gatewayInstance = new Gateway()

    return gatewayInstance


# Export setup function and database classes
module.exports = {

    setup: setupGateway

    #AbstractDatabase: .. # TODO
    DefaultDatabase: DefaultDatabase
}
