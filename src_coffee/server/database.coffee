
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
            database: Config.SQL_DATABASE_COMMON

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

    _toQuery: (wildValue) ->
        return mysql.escape(wildValue)

    _sendQuery: (sqlQuery) ->
        deferred = Q.defer()

        @connection.query sqlQuery, (err, resultData, fieldsMetaData) ->
            if err
                log.error(err, 'Database query')
                deferred.reject(err)
            else
                deferred.resolve(resultData)

        return deferred.promise

    _readSimpleData: (sqlQuery, rejectIfEmpty=false) ->
        promise = @_sendQuery(sqlQuery)
        promise = promise.then (resultRows) =>
            resultData = resultRows[0]
            if rejectIfEmpty and not resultData?
                throw new Error('Result is empty')
            return resultData
        return promise

    _readMultipleData: (sqlQuery) ->
        return @_sendQuery(sqlQuery)

    _get_game_db_name: (gameMetaData) ->
        return "#{Config.SQL_DATABASE_PREFIX_GAME}#{gameMetaData.database_id}"

    _get_game_table_name: (gameMetaData, tablePostfix) ->
        return "#{Config.SQL_TABLES.PREFIX_GAME_TABLE}#{gameMetaData.game_id}#{tablePostfix}"

    # Returns the saved identification data for the given player in the given game.
    # @param idPlayer [int] The id of the player's account or game character.
    # @param idGame [int] The id of the player's game world.
    # @return [promise] A promise, resolving to a data map with keys 
    #   `name` (The player's name), `id` (May equals idPlayer) and `idGame` (Equals idGame).
    #   If the read data set is empty, the promise is rejected. 
    getClientIdentityData: (idPlayer, idGame) ->
        # Read (meta) data of given game
        sql = "
                SELECT `ID` AS `game_id`, `RealityID` AS `database_id`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        promise = @_readSimpleData(sql, true)

        # Read data of given player in given game
        promise = promise.then (gameData) =>
            gameDatabase = @_get_game_db_name(gameData)
            playersTable = @_get_game_table_name(gameData, Config.SQL_TABLES.POSTFIX_GAME_PLAYERS)
            sql = "
                    SELECT `ID` AS `game_player_id`, `Folkname` AS `game_player_name`
                    FROM `#{gameDatabase}`.`#{playersTable}`
                    WHERE `UserID`=#{@_toQuery(idPlayer)}
                  "
            return @_readSimpleData(sql, true)

        promise = promise.then (playerData) =>
            unless playerData?
                throw new Error('Identity not found')
            return {
                id: playerData.game_player_id
                idGame: idGame
                name: playerData.game_player_name
            }

        return promise

    # Returns a list of channels, which were joined by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to read the channels for.
    # @return [promise] A promise, resolving to a list of objects, 
    #   each having at least the property `name`, which is the unique name of a channel.
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

