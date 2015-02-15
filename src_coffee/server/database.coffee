
## Include libraries
mysql = require 'mysql'
crypto = require 'crypto'

## Include app modules
Config = require './config'


## Abstraction of database interactions: Wraps the database of choice.
## Provides ready-to-use methods for all needed read/write operations.
##
## Structure:
## * Common connect/disconnect
## * Database query helper routines
## * Data value getters
## * Interface routines for app queries
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
            socketPath: Config.SQL_SOCKET_PATH

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

    #
    # Database query helper routines
    #

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

    _doTransaction: (transactionRoutineFunc) ->
        deferred = Q.defer()

        @connection.beginTransaction (err) ->
            if err
                log.error(err, 'Database transaction')
                deferred.reject(err)
            else
                routinePromise = transactionRoutineFunc()
                deferred.resolve(routinePromise)

        promise = deferred.promise
        promise = promise.then =>
            innerDeferred = Q.defer()
            @connection.commit (err) ->
                if err
                    log.error(err, 'Database transaction commit')
                    innerDeferred.reject(err)
                else
                    innerDeferred.resolve()
            return innerDeferred.promise
        promise.fail =>
            @connection.rollback()

        return promise

    _readSimpleData: (sqlQuery, rejectIfEmpty=false) ->
        promise = @_sendQuery(sqlQuery)
        promise = promise.then (resultRows) =>
            resultData = resultRows[0]
            if rejectIfEmpty and not resultData?
                err = new Error('Result is empty')
                err.isDatabaseResult = true
                throw err
            return resultData
        return promise

    _readMultipleData: (sqlQuery) ->
        return @_sendQuery(sqlQuery)


    #
    # Data value getters
    #

    createValidationError: (error_msg) ->
        err = new Error(error_msg)
        err.isValidation = true
        return err

    _get_hash_value: (original_val) ->
        hashingStream = crypto.createHash('md5')
        hashingStream.update(original_val);
        return hashingStream.digest('hex')

    _get_game_db_name: (gameMetaData) ->
        return "#{Config.SQL_DATABASE_PREFIX_GAME}#{gameMetaData.database_id}"

    _get_game_table_name: (gameMetaData, tablePostfix) ->
        return "#{Config.SQL_TABLES.PREFIX_GAME_TABLE}#{gameMetaData.game_id}#{tablePostfix}"

    # Returns the current security token for the given player. This token must be send on auth request by the client.
    _get_security_token: (idUser, playerData) ->
        return @_get_hash_value("#{Config.CLIENT_AUTH_SECRET}_#{idUser}_#{playerData.activity_stamp}")

    # Checks the given data for being valid to be passed to `createChannelByData()` and throws an error, if validation fails.
    # @param channelData [object] A data map with the channel data.
    # @throws Error if given data is invalid. The error is flagged as validation error.
    getValidatedChannelDataForCreation: (channelData) ->
        channelData.title = String(channelData.title or '').trim()
        channelData.password = String(channelData.password or '').trim()
        channelData.is_for_irc = !!channelData.is_for_irc
        channelData.is_public = !!channelData.is_public

        # Replace all (multiple) whitespace chars by space-char
        channelData.title = channelData.title.replace(/\s/g, ' ').replace(/[ ]+/g, ' ')

        # Do checks
        if not channelData.game_id or not channelData.title
            throw @createValidationError('Invalid input')

        unless 4 <= channelData.title.length <= 30
            throw @createValidationError('Illegal length of channel name')

        if Config.REQUIRE_CHANNEL_PW and 2 >= channelData.password.length
            throw @createValidationError('Channel password too short')

        unless channelData.password.length <= 20
            throw @createValidationError('Channel password too long')

        return channelData


    #
    # Interface routines for app queries
    #

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

    # Returns the status (textual or numerical) for the given game world. This is used by a bot on game status request.
    # @param idGame [int] The id of the game world.
    # @return [promise] A promise, resolving to the game's status.
    #   If the read data set is empty, the promise is rejected. 
    getGameStatus: (idGame) ->
        sql = "
                SELECT `Status` AS `status`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        promise = @_readSimpleData(sql, true)
        promise = promise.then (data) =>
            return data?.status
        promise = promise.then (statusID) =>
            # Fetch text for status
            textData =
                '-1': 'Not released yet'
                '0': 'Not started yet'
                '1': 'Running'
                '2': 'Paused'
                '3': 'Finished / Terminated'
                '4': 'Evaluated and archived'
            return textData[String(statusID)]
        return promise

    # Returns the current round number for the given game world. This is used by a bot on game round request.
    # @param idGame [int] The id of the game world.
    # @return [promise] A promise, resolving to the game's round number.
    #   If the read data set is empty, the promise is rejected. 
    getGameRound: (idGame) ->
        sql = "
                SELECT `Round` AS `round`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        promise = @_readSimpleData(sql, true)
        promise = promise.then (data) =>
            return data?.round
        return promise

    # Returns the list of game worlds, which each have a bot to use for bot-channels.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `id` (The unique id of the game world) and
    #   `title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   The list may be empty, if there are no games at all.
    getBotRepresentedGames: ->
        sql = "
                SELECT `ID` AS `id`, `Galaxyname` AS `title`
                FROM `#{Config.SQL_TABLES.GAMES_LIST}`
                WHERE `Status`>=0
                ORDER BY `Status` ASC, `ID` ASC
                LIMIT #{Config.MAX_BOTS}
              "
        return @_readMultipleData(sql)

    # Returns a list of channels, which should be mirrored to IRC - each by only one bot. This excludes the global channel.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `game_id` (The id of the game, the bot to be used belongs to),
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `password` (The password for joining the channel - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined players have to be hidden; else FALSE).
    #   The list may be empty, if no appropriate channels exist.
    getSingleBotChannels: ->
        sql = "
                SELECT CONCAT(#{@_toQuery(Config.INTERN_NONGAME_CHANNEL_PREFIX)}, `C`.`ID`) AS `name`, 
                       `GalaxyID` AS `game_id`, `C`.`Title` AS `title`, `Password` AS `password`, 
                       `C`.`IrcChannel` AS `irc_channel`, `C`.`IsPublic` AS `is_public`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` AS `C`
                WHERE `C`.`IrcChannel` IS NOT NULL
              "
        return @_readMultipleData(sql)

    # Returns the data for the global channel, which should be mirrored to IRC by multiple bots.
    # @return [promise] A promise, resolving to a data map with keys
    #   `name` (The unique name of the channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `password` (Optional: The password for joining the channel on IRC - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to mirror) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE).
    getGlobalChannelData: ->
        promise = Q.fcall =>
            return {
                name: Config.INTERN_GLOBAL_CHANNEL_NAME
                title: Config.INTERN_GLOBAL_CHANNEL_TITLE
                irc_channel: Config.IRC_GLOBAL_CHANNEL
                is_public: true
            }
        return promise

    # Returns the data for the channel matching given game and title.
    # @param idGame [int] The id of the game world, the requested channel belongs to.
    # @param channelTitle [string] The title of the requested channel (is allowed to contain spaces, etc.).
    # @return [promise] A promise, resolving to a data map with keys
    #   `game_id` (The id of the game, a channel belongs to - should normally equal the given idGame),
    #   `name` (The unique name of the channel - used internally),
    #   `title` (The display name of the channel - should normally equal the given title),
    #   `password` (The password for joining the channel - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to optionally mirror) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE).
    #   If the read data set is empty, the promise is rejected. 
    getChannelDataByTitle: (idGame, channelTitle) ->
        sql = "
                SELECT CONCAT(#{@_toQuery(Config.INTERN_NONGAME_CHANNEL_PREFIX)}, `ID`) AS `name`, 
                       `GalaxyID` AS `game_id`, `Title` AS `title`, `Password` AS `password`, 
                       `IrcChannel` AS `irc_channel`, `IsPublic` AS `is_public`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}`
                WHERE `GalaxyID`=#{@_toQuery(idGame)}
                  AND `Title` LIKE #{@_toQuery(channelTitle)}
              "
        return @_readSimpleData(sql, true)

    # Returns a list of channels, which were joined by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to read the channels for.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `irc_channel` (Optional: The exact name of an IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined player's have to be hidden; else FALSE).
    #   The list may be empty, if no channels are joined by the client.
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
                  AND `C`.`GalaxyID`=#{@_toQuery(idGame)}
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
        resultPromise = resultPromise.then (channelListData) =>
            return channelListData.reverse()  # Reverse channel order: Default channel first, then galaxy, then individual ones...

        return resultPromise

    # Returns the number of channels, which were created by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to count the channels for.
    # @return [promise] A promise, resolving to the number of channels.
    getClientCreatedChannelsCount: (clientIdentity) ->
        idGame = clientIdentity.getGameID()
        idUser = clientIdentity.getUserID()
        sql = "
                SELECT COUNT(`ID`) AS `channels`
                FROM `#{Config.SQL_TABLES.CHANNEL_LIST}`
                WHERE `GalaxyID`=#{@_toQuery(idGame)}
                  AND `CreatorUserID`=#{@_toQuery(idUser)}
              "
        promise = @_readSimpleData(sql)
        promise = promise.then (data) =>
            return data?.channels
        return promise

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


    # Returns a list of messages/channel events, which had been logged for the given channel.
    # @param channelName [string] The internal name of the channel.
    # @return [promise] A promise, resolving to a list of data maps, each having keys 
    #   `id` (The id of the list entry),
    #   `event_name` (The name of the logged channel event),
    #   `event_data` (The logged data for the event, serialized as JSON string - contains values like message text or sender identity) and
    #   `timestamp` (The timestamp of the log entry/event).
    #   The list may be empty, if no logs exists for the channel.
    getLoggedChannelMessages: (channelName) ->
        sql = "
                (
                    SELECT `ChannelLogID` AS `id`, `EventTextID` AS `event_name`, `EventData` AS `event_data`, `Timestamp` AS `timestamp`
                    FROM `#{Config.SQL_TABLES.CHANNEL_LOGS}`
                    WHERE `ChannelTextID`=#{@_toQuery(channelName)}
                    ORDER BY `Timestamp` DESC
                    LIMIT #{Config.MAX_CHANNEL_LOGS_TO_CLIENT}
                )
                ORDER BY `Timestamp` ASC
              "
        promise = @_readMultipleData(sql)
        return promise

    # Saves the given message/channel event to the channel logs. May replaces old logs.
    # @param channelName [string] The internal name of the channel.
    # @param timestamp [int] The timestamp of the event (in milliseconds).
    # @param eventName [string] The name of the channel event.
    # @param eventData [object] A data map, containing the main data for the event (like message text or sender identity).
    logChannelMessage: (channelName, timestamp, eventName, eventData) ->
        channelID = 0
        if channelName.indexOf(Config.INTERN_NONGAME_CHANNEL_PREFIX) is 0
            channelID = channelName.replace(Config.INTERN_NONGAME_CHANNEL_PREFIX, '')
        serialEventData = JSON.stringify(eventData)

        @_doTransaction =>
            sql = "
                    SELECT COALESCE(MAX(`ChannelLogID`), 0) AS `max_id`
                    FROM `#{Config.SQL_TABLES.CHANNEL_LOGS}`
                    WHERE `ChannelTextID`=#{@_toQuery(channelName)}
                  "
            promise = @_readSimpleData(sql, true)
            promise = promise.then (data) =>
                maxLogID = data.max_id
                nextLogID = maxLogID + 1
                nextBufferID = (maxLogID % Config.MAX_CHANNEL_LOGS) + 1
                sql = "
                        REPLACE INTO `#{Config.SQL_TABLES.CHANNEL_LOGS}` SET
                           `ChannelLogID`=#{@_toQuery(nextLogID)},
                           `ChannelBufferID`=#{@_toQuery(nextBufferID)},
                           `ChannelTextID`=#{@_toQuery(channelName)},
                           `ChannelID`=#{@_toQuery(channelID)},
                           `EventTextID`=#{@_toQuery(eventName)},
                           `EventData`=#{@_toQuery(serialEventData)},
                           `Timestamp`=#{@_toQuery(timestamp)}
                      "
                return @_sendQuery(sql)
            return promise


    # Creates a new channel with given data and returns the resulting data of the channel in database.
    # @param clientIdentity [ClientIdentity] The identity of the client to set as channel creator.
    # @param channelData [object] A data map with keys
    #   `game_id` (The id of the game, a channel should belong to),
    #   `title` (The display name for the channel - is allowed to contain spaces, etc.),
    #   `password` (The password for joining the channel - not encrypted),
    #   `is_for_irc` (TRUE, if the channel should to be mirrored to IRC; else FALSE - Defaults to FALSE) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE - Defaults to FALSE).
    # @return [promise] A promise, resolving to a data map with keys equal to the given object, but complemented with keys
    #   `name` (The unique name of the channel - used internally) and
    #   `irc_channel` (The exact name of an IRC channel to mirror - Defaults to null, if `is_for_irc` was false).
    #   If the channel could not be created, the promise is rejected. 
    createChannelByData: (clientIdentity, channelData) ->
        # Create the channel
        idUser = clientIdentity.getUserID()
        sql = "
                INSERT INTO `#{Config.SQL_TABLES.CHANNEL_LIST}` SET
                    `GalaxyID`=#{@_toQuery(channelData.game_id)},
                    `CreatorUserID`=#{@_toQuery(idUser)},
                    `Title`=#{@_toQuery(channelData.title)},
                    `Password`=#{@_toQuery(channelData.password)},
                    `IsPublic`=#{@_toQuery(channelData.is_public)}
              "
        promise = @_sendQuery(sql)

        # Finalize result object
        promise = promise.then (resultData) =>
            channelID = resultData.insertId

            # Add channel name to data object
            channelName = "#{Config.INTERN_NONGAME_CHANNEL_PREFIX}#{channelID}"
            channelData.name = channelName

            # Add irc channel name
            if channelData.is_for_irc
                randomID = Math.floor(Math.random() * 1000)
                ircChannelName = "#{Config.IRC_NONGAME_CHANNEL_PREFIX}#{channelID}_#{randomID}"
                channelData.irc_channel = ircChannelName

                # Save name of irc channel
                sql = "
                        UPDATE `#{Config.SQL_TABLES.CHANNEL_LIST}` SET
                            `IrcChannel`=#{@_toQuery(ircChannelName)}
                        WHERE `ID`=#{@_toQuery(channelID)}
                      "
                @_sendQuery(sql)
            return channelData

        return promise

    # Deletes all related data (logs, joinings, etc.) of all channels, which belong to the given game.
    # @param gameID [int] The id of the game world.
    deleteChannelsByGame: (gameID) ->
        internalGameChannel = "#{Config.INTERN_GAME_CHANNEL_PREFIX}#{gameID}"

        # Delete channel logs
        sql = "
                DELETE FROM `#{Config.SQL_TABLES.CHANNEL_LOGS}` 
                WHERE `ChannelID` IN (
                    SELECT `ID` FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` 
                    WHERE `GalaxyID`=#{@_toQuery(gameID)}
                )
                OR `ChannelTextID`=#{@_toQuery(internalGameChannel)}
              "
        logsPromise = @_sendQuery(sql)

        # Delete channel joinings
        sql = "
                DELETE FROM `#{Config.SQL_TABLES.CHANNEL_JOININGS}` 
                WHERE `ChannelID` IN (
                    SELECT `ID` FROM `#{Config.SQL_TABLES.CHANNEL_LIST}` 
                    WHERE `GalaxyID`=#{@_toQuery(gameID)}
                )
              "
        joinsPromise = @_sendQuery(sql)

        # Delete channels
        Q.all([logsPromise, joinsPromise]).then =>
            sql = "
                    DELETE FROM `#{Config.SQL_TABLES.CHANNEL_LIST}`
                    WHERE `GalaxyID`=#{@_toQuery(gameID)}
                  "
            @_sendQuery(sql)



    addClientToChannel: (client, channelName) ->
        return unless channelName.indexOf(Config.INTERN_NONGAME_CHANNEL_PREFIX) is 0  # Only non-game channels can be joined explicitly
        channelID = channelName.replace(Config.INTERN_NONGAME_CHANNEL_PREFIX, '')
        # TODO

    removeClientFromChannel: (client, channelName) ->
        # TODO
        # Only allow parting on channels not created by the client



## Export class
module.exports = Database

