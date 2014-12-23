
## Include libraries
mysql = require 'mysql'
crypto = require 'crypto'

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

    _get_hash_value: (original_val) ->
        hashingStream = crypto.createHash('md5')
        hashingStream.update(original_val);
        return hashingStream.digest('hex')

    _get_game_db_name: (gameMetaData) ->
        return "#{Config.SQL_DATABASE_PREFIX_GAME}#{gameMetaData.database_id}"

    _get_game_table_name: (gameMetaData, tablePostfix) ->
        return "#{Config.SQL_TABLES.PREFIX_GAME_TABLE}#{gameMetaData.game_id}#{tablePostfix}"

    # Returns the current security token for the given player. This token must be send on auth request by the client.
    _get_security_token: (idPlayer, playerData) ->
        return @_get_hash_value("#{Config.CLIENT_AUTH_SECRET}_#{idPlayer}_#{playerData.activity_stamp}")

    # Returns the data for the given game world.
    # @param idGame [int] The id of the game world.
    # @return [promise] A promise, resolving to a data map with keys 
    #   `game_id` (Should equal idGame), 
    #   `database_id` (The id of the database, which stores the game tables) and
    #   `game_title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   If the read data set is empty, the promise is rejected. 
    _getGameData: (idGame) ->
        sql = "
                SELECT `ID` AS `game_id`, `RealityID` AS `database_id`, `Galaxyname` AS `game_title`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        return @_readSimpleData(sql, true)

    # Returns the list of game worlds, which each have a bot to use for bot-channels.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `id` (The unique id of the game world) and
    #   `title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   The list may be equal, if there are no games at all.
    getBotRepresentedGames: ->
        sql = "
                SELECT `ID` AS `id`, `Galaxyname` AS `title`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `Status`>=0

                ORDER BY ID DESC
                LIMIT 2
              "   # TODO: Remove limit and order by!

        # TODO Order clause:
        # ORDER BY `Status` ASC, `ID` ASC
        # LIMIT #{Config.MAX_BOTS}


        return @_readMultipleData(sql)

    # Returns a list of channels, which should be mirrored to IRC - each by only one bot. This excludes the global channel.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `game_id` (The id of the game, the bot to be used belongs to),
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `irc_channel` (The exact name of the IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined player's have to be hidden; else FALSE).
    #   The list may be equal, if no appropriate channels exist.
    getSingleBotChannels: ->
        sql = "
                SELECT CONCAT(#{@_toQuery(Config.INTERN_NONGAME_CHANNEL_PREFIX)}, `C`.`ID`) AS `name`, 
                       `C`.`Title` AS `title`, `C`.`IrcChannel` AS `irc_channel`, `C`.`IsPublic` AS `is_public`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` AS `C`
                WHERE `C`.`IrcChannel` IS NOT NULL
              "
        return @_readMultipleData(sql)

    # TODO: docs
    getGlobalChannelData: ->
        promise = Q.fcall =>
            return {
                name: Config.INTERN_GLOBAL_CHANNEL_NAME
                title: Config.INTERN_GLOBAL_CHANNEL_TITLE
                irc_channel: Config.IRC_GLOBAL_CHANNEL
                is_public: true
            }
        return promise

    # Returns a list of channels, which were joined by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to read the channels for.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `irc_channel` (Optional: The exact name of an IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined player's have to be hidden; else FALSE).
    #   The list may be equal, if no channels are joined by the client.
    getClientChannels: (clientIdentity) ->
        # Read data of client's game as default channel
        idGame = clientIdentity.getGameID()
        gamePromise = @_getGameData(idGame)
        gamePromise = gamePromise.then (gameData) =>
            return {
                name: "#{Config.INTERN_GAME_CHANNEL_PREFIX}#{gameData.game_id}"
                title: gameData.game_title
                is_public: true
            }

        # Read non-default channels
        idUser = clientIdentity.getUserID()
        sql = "
                SELECT CONCAT(#{@_toQuery(Config.INTERN_NONGAME_CHANNEL_PREFIX)}, `C`.`ID`) AS `name`, 
                       `C`.`Title` AS `title`, `C`.`IrcChannel` AS `irc_channel`, `C`.`IsPublic` AS `is_public`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` AS `C`
                JOIN `#{Config.SQL_TABLES.CHANNEL_JOININGS}` AS `CJ`
                  ON `CJ`.`ChannelID`=`C`.`ID`
                WHERE `CJ`.`UserID`=#{@_toQuery(idUser)}
              "
        channelsPromise = @_readMultipleData(sql)

        # Read data of default channel
        globalChannelPromise = @getGlobalChannelData()

        # Merge promise results to one array
        resultPromise = channelsPromise.then (channelListData) =>
            list = channelListData
            return gamePromise.then (gameChannelData) =>
                list.push(gameChannelData) if gameChannelData?
                return globalChannelPromise.then (defaultChannelData) =>
                    list.push(defaultChannelData)
                    return list

        return resultPromise

    # Returns the saved identification data for the given player in the given game.
    # @param idUser [int] The id of the player's account or game identity/character as given by a client on logon.
    # @param idGame [int] The id of the player's game world as given by a client on logon.
    # @return [promise] A promise, resolving to a data map with keys 
    #   `name` (The player's name for the chat), 
    #   `id` (The id of the player for the chat), 
    #   `idGame` (Should equal idGame), 
    #   `idUser` (The id of the player's account) and 
    #   `token` (The security token for the player).
    #   If the read data set is empty, the promise is rejected.
    getClientIdentityData: (idUser, idGame) ->
        # Read (meta) data of given game
        promise = @_getGameData(idGame)

        # Read data of given player in given game
        promise = promise.then (gameData) =>
            gameDatabase = @_get_game_db_name(gameData)
            playersTable = @_get_game_table_name(gameData, Config.SQL_TABLES.POSTFIX_GAME_PLAYERS)
            sql = "
                    SELECT `ID` AS `game_identity_id`, `Folkname` AS `game_identity_name`, `LastActivityStamp` AS `activity_stamp`
                    FROM `#{gameDatabase}`.`#{playersTable}`
                    WHERE `UserID`=#{@_toQuery(idUser)}
                  "
            return @_readSimpleData(sql, true)

        promise = promise.then (playerData) =>
            return {
                id: playerData.game_identity_id
                idGame: idGame
                idUser: idUser
                name: playerData.game_identity_name
                token: @_get_security_token(idUser, playerData)
            }

        return promise


    # OLD: TO BE removed
    getChannelData: (channelIdent) ->
        # TODO
        sql = "
                SELECT `C`.`ID` AS `channel_id`, `C`.`Title` AS `channel_title`, 
                       `C`.`IrcChannel` AS `irc_channel`, `C`.`IsPublic` AS `is_public`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` AS `C`
                JOIN `#{Config.SQL_TABLES.CHANNEL_JOININGS}` AS `CJ`
                  ON `CJ`.`ChannelID`=`C`.`ID`
                WHERE `CJ`.`UserID`=#{@_toQuery(idUser)}

              "

        # TODO: TEMP
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

