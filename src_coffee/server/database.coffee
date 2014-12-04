
## Include libraries
mysql = require 'mysql'

## Include app modules
Config = require './config'


## Class definition - Database:
## Wraps the database of choice.
## Provides ready-to-use methods for all needed read/write operations.
##
class Database

    connection: null


    connect: ->
        deferred = Q.defer()

        ## Open connection to database
        @connection = mysql.createConnection
            host: Config.SQL_HOST
            port: Config.SQL_PORT
            user: Config.SQL_USER
            password: Config.SQL_PASSWORD
            database: Config.SQL_DATABASE

        @connection.connect (err) =>
            if err
                log.error(err, 'Database connection')
                deferred.reject(err)
            else
                log.debug 'Established database connection'
                deferred.resolve()

        return deferred.promise

    disconnect: ->
        deferred = Q.defer()

        if @connection.state is 'disconnected'
            @connection.destroy()
        else
            @connection.end (err) =>
                if err
                    log.error(err, 'Database disconnect')
                else
                    log.debug 'Closed database connection'
                @connection.destroy()
                deferred.resolve()

        return deferred.promise

    _sendQuery: (sqlQuery) ->
        deferred = Q.defer()

        @connection.query sqlQuery, (err, rows, fields) ->
            if err
                log.error(err, 'Database query')
                deferred.reject(err)
            else
                deferred.resolve({rows, fields})  # TODO: What is fields? Can we pass 2 arguments to deferred.resolve()?

        return deferred.promise


    # Returns the saved identification data for the given player in the given game.
    # @param idPlayer [int] The id of the player's account or game character.
    # @param idGame [int] The id of the player's game world.
    # @return [object] A data map with keys `name` (The player's name), `id` (May equals idPlayer) and `idGame` (Equals idGame).
    getClientIdentityData: (idPlayer, idGame) ->
        # TODO: Is idPlayer the FolkID or UserID?
        # Return at least Folkname (or Username??? -> Can be chosen by user?)


    # Returns a list of channels, which were joined by the given client.
    # @param clientIdentity [object] The ClientIdentity instance of the client to read the channels for.
    # @return [Array] A list of objects, each having at least the property `name`, which is the unique name of a channel.
    getClientChannels: (clientIdentity) ->
        # TODO
        # db.select("Select channel from channels, client_channels where client = '#{clientIdent}'")

        tempdata = [
                #id: 123
                name: 'galaxy_test'
            ,
                #id: 124
                name: 'galaxy_test_group01'
        ]

        return tempdata

    getChannelData: (channelIdent) ->
        tempdata = {
            'galaxy_test':
                title: 'Test-Galaxie'
                is_public: true
            'galaxy_test_group01':
                title: 'Ally 1'
                is_public: false
        }

        tempdata[Config.INTERN_BOT_CHANNEL_NAME] =
            title: 'SGR Support'
            is_public: true

        return tempdata[channelIdent]

    addClientToChannel: (client, channelIdent) ->
        # TODO

    removeClientFromChannel: (client, channelIdent) ->
        # TODO

    saveSingleValue: (namespace, key, value) ->
        # TODO
        # db.table("values").update(namespace + '_' + key, value)




## Export class
module.exports = Database

