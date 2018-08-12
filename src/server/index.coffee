##
## Package main file
##

# Include app modules for setup
config = require './config'
dataloader = require './datasources/loader'

# Include datasource classes
AbstractDatasource = require './datasources/ds.abstract'
DefaultDatasource = require './datasources/ds.default'
SgrDatasource = require './datasources/ds.sgr'

# Include database handler classes
AbstractDatabaseHandler = require './databasehandlers/dbh.abstract'
MysqlDatabaseHandler = require './databasehandlers/dbh.mysql'


# Setup mechanism
#
gatewayInstance = null

setupGateway = (customConfig, customDatasourceClass) ->
    # Set up config
    if config._overwriteDefaults?
        if customConfig?
            config._overwriteDefaults(customConfig)
            config._overwriteDefaults = null
        else
            console.error('\nMissing configuration settings for IRC gateway!\n')
    else if customConfig?
        console.warn('\nIRC gateway already created, cannot change its config!\n')

    # Set up datasource class
    if customDatasourceClass?.prototype instanceof AbstractDatasource
        dataloader.setClass(customDatasourceClass)
    else
        console.error('\nGiven datasource class does not inherit from "AbstractDatasource", it cannot be used for the IRC gateway!\n')

    # Get gateway instance
    unless gatewayInstance?
        Gateway = require('./app')  # Lazy load, so injected config and datasource will be used
        gatewayInstance = new Gateway()

    return gatewayInstance


# Export setup function and datasource classes
module.exports = {

    setup: setupGateway

    AbstractDatabaseHandler: AbstractDatabaseHandler
    MysqlDatabaseHandler: MysqlDatabaseHandler

    AbstractDatasource: AbstractDatasource
    DefaultDatasource: DefaultDatasource
    SgrDatasource: SgrDatasource

}
