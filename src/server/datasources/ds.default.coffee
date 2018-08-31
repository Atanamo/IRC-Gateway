
## Include libraries
Q = require 'q'
crypto = require 'crypto'

## Include app modules
config = require '../config'
log = require '../logger'

## Include data classes
MysqlDatabaseHandler = require '../databasehandlers/dbh.mysql'
AbstractDatasource = require './ds.abstract'


## Default abstraction of data managing methods.
## See `AbstractDatasource` for more.
##
## Uses the MySQL database handler by default.
##
## Structure:
## * Client identity (with example implementations)
## * Game-specific queries (with example implementations)
## * Server management
## * Channel management
##
class DefaultDatasource extends AbstractDatasource

    # @override
    _createHandler: ->
        return new MysqlDatabaseHandler(config, log)


    #
    # Client identity (with example implementations)
    #

    # Returns the saved identification data for the given player in the given game.
    # @param idUser [int] The id of the player's account or game identity/character as given by a client on logon.
    # @param idGame [int] The id of the player's game world as given by a client on logon.
    # @return [promise] A promise, resolving to a data map with keys
    #   `id` (The id of the player for the chat),
    #   `idGame` (Should equal given idGame),
    #   `idUser` (The id of the player's account),
    #   `name` (The player's name for the chat),
    #   `title` (An optional more detail name for the chat, will default to the name),
    #   `gameTitle` (The full name of the player's game world),
    #   `gameTag` (An optional shortened version of the name of the player's game world, will default to the full name),
    #   `token` (The security token for the player).
    #   If the read data set is empty, the promise is rejected.
    getClientIdentityData: (idUser, idGame) ->
        ##
        # Note: This is an example implementation - overwrite it for your own game API
        ##

        # Read (meta) data of given game
        promise = @_getGameData(idGame)

        # Read data of given player in given game
        promise = promise.then (gameData) =>
            sql = "
                    SELECT `Ch`.`ID` AS `character_id`,
                           `Ch`.`Name` AS `character_name`,
                           `Ch`.`Class` AS `class_name`,
                           #{@_toQuery(gameData.game_title)} AS `game_title`
                    FROM `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.PLAYER_GAMES}` AS `PG`
                    JOIN `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.GAME_PLAYER_IDENTITIES}` AS `Ch`
                      ON `Ch`.`ID`=`PG`.`CharacterID`
                    WHERE `PG`.`GameID`=#{@_toQuery(idGame)}
                      AND `PG`.`UserID`=#{@_toQuery(idUser)}
                  "
            return @_readSimpleData(sql, true)

        # Build final result
        promise = promise.then (playerData) =>
            return {
                id: playerData.character_id
                idGame: idGame
                idUser: idUser
                name: playerData.character_name
                title: "#{playerData.character_name} - #{playerData.class_name}"
                gameTitle: playerData.game_title
                gameTag: @_getShortenedGameTitle(playerData.game_title)
                token: @_getSecurityToken(idUser, playerData)
            }

        return promise

    # Returns the current security token for the given player.
    # This token must be sent on auth request by the client.
    _getSecurityToken: (idUser, playerData) ->
        return @_getHashValue("#{config.CLIENT_AUTH_SECRET}_#{idUser}")

    # Returns the md5 hash of the given string
    _getHashValue: (original_val) ->
        hashingStream = crypto.createHash('md5')
        hashingStream.update(original_val);
        return hashingStream.digest('hex')

    # Returns the first part of the given game title (split by underscore, hyphen or space)
    _getShortenedGameTitle: (fullGameTitle) ->
        shortTitle = String(fullGameTitle)
        shortTitle = shortTitle.replace(/[_- ](.+)/, '')
        return shortTitle


    #
    # Game-specific queries (with example implementations)
    #

    # Helper query - Returns the data for the given game world.
    # @param idGame [int] The id of the game world.
    # @return [promise] A promise, resolving to a data map with keys
    #   `game_id` (Should equal idGame),
    #   `database_id` (The id of the database, which stores the game tables) and
    #   `game_title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   If the read data set is empty, the promise is rejected.
    _getGameData: (idGame) ->
        ##
        # Note: This is an example implementation - overwrite it for your own requirements
        ##

        sql = "
                SELECT `ID` AS `game_id`, `ServerID` AS `database_id`, `Name` AS `game_title`
                FROM `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        return @_readSimpleData(sql, true)

    # Returns the status information for each of the given list of game worlds.
    # This is used by a bot on request of one or more game statuses.
    # @param idList [array] An array of integers, each defining the id of a game world.
    # @return [promise] A promise, resolving to a list of data maps.
    #   Each data map must have at least the key `id` to reference the corresponding game world.
    #   The bot will output any further values of a data map as a game's status information.
    #   (The key of each of these values is used to label the value on output. Underscores are replaced by spaces.)
    #   The list may be empty, if none of the given games could be found.
    getGameStatuses: (idList=[]) ->
        ##
        # Note: This is an example implementation - overwrite it for your own game API
        ##

        # Convert given array to string of comma-separated values
        idListSanitized = idList.map (idGame) =>
            @_toQuery(idGame)
        idListString = idListSanitized.join(',')

        # Read the status values 'current_state' and 'start_time' for each game:
        sql = "
                SELECT `ID` as `id`, `StateText` AS `current_state`, `StartTime` AS `start_time`
                FROM `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID` IN (#{idListString})
                ORDER BY `Status` ASC, `ID` DESC
              "
        return @_readMultipleData(sql)

    # Returns the list of game worlds, which each have a bot to use for bot-channels.
    # If the mono-bot is configured, returns the list of all game worlds having a chat.
    # This list is also used to manage the lifetime of corresponding channels and its logs
    # by the game lookup interval.
    # @return [promise] A promise, resolving to a list of data maps, each having keys
    #   `id` (The unique id of the game world) and
    #   `title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   The list may be empty, if there are no games at all.
    getBotRepresentedGames: ->
        ##
        # Note: This is an example implementation - overwrite it for your own game API
        ##

        if config.MAX_BOTS > 0
            sql = "
                    SELECT `ID` AS `id`, `Name` AS `title`
                    FROM `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.GAMES_LIST}`
                    WHERE `Running`=1 AND `Deleted`=0
                    ORDER BY `ID` ASC
                    LIMIT #{config.MAX_BOTS}
                "
        else
            sql = "
                    SELECT `ID` AS `id`, `Name` AS `title`
                    FROM `#{config.SQL_DATABASE_GAME}`.`#{config.SQL_TABLES.GAMES_LIST}`
                    WHERE `Deleted`=0
                    ORDER BY `ID` ASC
                "
        return @_readMultipleData(sql)


    #
    # Server management
    #

    # Returns a list of channels, which should be mirrored to IRC, but each belong to only one game.
    # This excludes the global channel.
    # @return [promise] A promise, resolving to a list of data maps, each having keys
    #   `game_id` (The id of the game, the channel belongs to),
    #   `creator_id` (The id of the user, who created the channel),
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `password` (The password for joining the channel - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined players have to be hidden; else FALSE).
    #   The list may be empty, if no appropriate channels exist.
    getGameBoundBotChannels: ->
        sql = "
                SELECT CONCAT(#{@_toQuery(config.INTERN_NONGAME_CHANNEL_PREFIX)}, `ID`) AS `name`,
                       `GameID` AS `game_id`, `CreatorUserID` AS `creator_id`,
                       `Title` AS `title`, `Password` AS `password`,
                       `IrcChannel` AS `irc_channel`, `IsPublic` AS `is_public`
                FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                WHERE `IrcChannel` IS NOT NULL
              "
        return @_readMultipleData(sql)

    # Returns the data for the global channel, which should be mirrored to IRC for every game world.
    # Thus, if not using the mono-bot, it will contain multiple bots.
    # @return [promise] A promise, resolving to a data map with keys
    #   `name` (The unique name of the channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `password` (Optional: The password for joining the channel on IRC - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to mirror) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE).
    getGlobalChannelData: ->
        promise = Q.fcall =>
            return {
                name: config.INTERN_GLOBAL_CHANNEL_NAME
                title: config.INTERN_GLOBAL_CHANNEL_TITLE
                irc_channel: config.IRC_GLOBAL_CHANNEL
                is_public: true
            }
        return promise

    # Returns the data for the channel matching given game and title.
    # @param idGame [int] The id of the game world, the requested channel belongs to.
    # @param channelTitle [string] The title of the requested channel (is allowed to contain spaces, etc.).
    # @return [promise] A promise, resolving to a data map with keys
    #   `game_id` (The id of the game, a channel belongs to - should normally equal the given idGame),
    #   `creator_id` (The id of the user, who created the channel),
    #   `name` (The unique name of the channel - used internally),
    #   `title` (The display name of the channel - should normally equal the given title),
    #   `password` (The password for joining the channel - not encrypted),
    #   `irc_channel` (The exact name of the IRC channel to optionally mirror) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE).
    #   If the read data set is empty, the promise is rejected.
    getChannelDataByTitle: (idGame, channelTitle) ->
        sql = "
                SELECT CONCAT(#{@_toQuery(config.INTERN_NONGAME_CHANNEL_PREFIX)}, `ID`) AS `name`,
                       `GameID` AS `game_id`, `CreatorUserID` AS `creator_id`,
                       `Title` AS `title`, `Password` AS `password`,
                       `IrcChannel` AS `irc_channel`, `IsPublic` AS `is_public`
                FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                WHERE `GameID`=#{@_toQuery(idGame)}
                  AND `Title` LIKE #{@_toQuery(channelTitle)}
              "
        return @_readSimpleData(sql, true)

    # Returns a list of channels, which were joined by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to read the channels for.
    # @return [promise] A promise, resolving to a list of data maps, each having keys
    #   `name` (The unique name of a channel - used internally),
    #   `title` (The display name of the channel - is allowed to contain spaces, etc.),
    #   `creator_id` (Optional: The id of the user, who created the channel),
    #   `irc_channel` (Optional: The exact name of an IRC channel to mirror) and
    #   `is_public` (TRUE, if the channel is meant to be public and therefor joined player's have to be hidden; else FALSE).
    #   The list may be empty, if no channels are joined by the client.
    getClientChannels: (clientIdentity) ->
        # Read data of client's game as default channel
        idGame = clientIdentity.getGameID()
        gamePromise = @_getGameData(idGame)
        gamePromise = gamePromise.then (gameData) =>
            return {
                name: "#{config.INTERN_GAME_CHANNEL_PREFIX}#{gameData.game_id}"
                title: gameData.game_title
                is_public: true
            }

        # Read non-default channels
        idUser = clientIdentity.getUserID()
        sql = "
                SELECT CONCAT(#{@_toQuery(config.INTERN_NONGAME_CHANNEL_PREFIX)}, `C`.`ID`) AS `name`,
                       `C`.`CreatorUserID` AS `creator_id`, `C`.`Title` AS `title`,
                       `C`.`IrcChannel` AS `irc_channel`, `C`.`IsPublic` AS `is_public`
                FROM `#{config.SQL_TABLES.CHANNEL_LIST}` AS `C`
                JOIN `#{config.SQL_TABLES.CHANNEL_JOININGS}` AS `CJ`
                  ON `CJ`.`ChannelID`=`C`.`ID`
                WHERE `CJ`.`UserID`=#{@_toQuery(idUser)}
                  AND `C`.`GameID`=#{@_toQuery(idGame)}
                ORDER BY `CJ`.`ID` ASC
              "
        channelsPromise = @_readMultipleData(sql)

        # Read data of default channel
        globalChannelPromise = @getGlobalChannelData()

        # Merge promise results to one array
        resultPromise = channelsPromise.then (channelListData) =>
            list = channelListData
            return gamePromise.then (gameChannelData) =>
                list.unshift(gameChannelData) if gameChannelData?
                return globalChannelPromise.then (defaultChannelData) =>
                    list.unshift(defaultChannelData)
                    return list
        return resultPromise

    # Returns the number of channels, which were created by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to count the channels for.
    # @return [promise] A promise, resolving to the number of channels.
    getClientCreatedChannelsCount: (clientIdentity) ->
        idGame = clientIdentity.getGameID()
        idUser = clientIdentity.getUserID()
        sql = "
                SELECT COUNT(`ID`) AS `channels`
                FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                WHERE `GameID`=#{@_toQuery(idGame)}
                  AND `CreatorUserID`=#{@_toQuery(idUser)}
              "
        promise = @_readSimpleData(sql)
        promise = promise.then (data) =>
            return data?.channels
        return promise


    #
    # Channel management
    #

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
                    FROM `#{config.SQL_TABLES.CHANNEL_LOGS}`
                    WHERE `ChannelTextID`=#{@_toQuery(channelName)}
                    ORDER BY `Timestamp` DESC
                    LIMIT #{config.MAX_CHANNEL_LOGS_TO_CLIENT}
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
        if channelName.indexOf(config.INTERN_NONGAME_CHANNEL_PREFIX) is 0
            channelID = channelName.replace(config.INTERN_NONGAME_CHANNEL_PREFIX, '')

        try
            serialEventData = JSON.stringify(eventData)
        catch
            log.warn 'Could not serializable json string!', 'Database message logging'
            serialEventData = '{}'

        @_doTransaction =>
            sql = "
                    SELECT COALESCE(MAX(`ChannelLogID`), 0) AS `max_id`
                    FROM `#{config.SQL_TABLES.CHANNEL_LOGS}`
                    WHERE `ChannelTextID`=#{@_toQuery(channelName)}
                  "
            promise = @_readSimpleData(sql, true)
            promise = promise.then (data) =>
                maxLogID = data.max_id
                nextLogID = maxLogID + 1
                nextBufferID = (maxLogID % config.MAX_CHANNEL_LOGS) + 1
                sql = "
                        REPLACE INTO `#{config.SQL_TABLES.CHANNEL_LOGS}` SET
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
    #   `is_for_irc` (TRUE, if the channel should to be mirrored to IRC; else FALSE - defaults to FALSE) and
    #   `is_public` (TRUE, if players joined to the channel should to be hidden; else FALSE - defaults to FALSE).
    # @return [promise] A promise, resolving to a data map with keys equal to the given object, but complemented with keys
    #   `creator_id` (The id of the user, who created the channel - should equal user id of given identity),
    #   `name` (The unique name of the channel - used internally) and
    #   `irc_channel` (The exact name of an IRC channel to mirror - defaults to null, if `is_for_irc` was false).
    #   If the channel could not be created, the promise is rejected.
    createChannelByData: (clientIdentity, channelData) ->
        # Create the channel
        userID = clientIdentity.getUserID()
        channelData.creator_id = userID
        sql = "
                INSERT INTO `#{config.SQL_TABLES.CHANNEL_LIST}` SET
                    `GameID`=#{@_toQuery(channelData.game_id)},
                    `CreatorUserID`=#{@_toQuery(userID)},
                    `Title`=#{@_toQuery(channelData.title)},
                    `Password`=#{@_toQuery(channelData.password)},
                    `IsPublic`=#{@_toQuery(channelData.is_public)}
              "
        promise = @_sendQuery(sql)

        # Finalize result object
        promise = promise.then (resultData) =>
            channelID = resultData.insertId

            # Add channel name to data object
            channelName = "#{config.INTERN_NONGAME_CHANNEL_PREFIX}#{channelID}"
            channelData.name = channelName

            # Add irc channel name
            if channelData.is_for_irc
                randomID = Math.floor(Math.random() * 1000)
                ircChannelName = "#{config.IRC_NONGAME_CHANNEL_PREFIX}#{channelID}_#{randomID}"
                channelData.irc_channel = ircChannelName

                # Save name of irc channel
                sql = "
                        UPDATE `#{config.SQL_TABLES.CHANNEL_LIST}` SET
                            `IrcChannel`=#{@_toQuery(ircChannelName)}
                        WHERE `ID`=#{@_toQuery(channelID)}
                      "
                @_sendQuery(sql)
            return channelData

        return promise

    # Deletes all related data (logs, joinings, etc.) of the channel with the given game.
    # @param channelName [string] The internal name of the channel to delete.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    deleteChannel: (channelName) ->
        return unless channelName.indexOf(config.INTERN_NONGAME_CHANNEL_PREFIX) is 0  # Only non-game channels can be deleted
        channelID = channelName.replace(config.INTERN_NONGAME_CHANNEL_PREFIX, '')

        # Delete channel logs
        sql = "
                DELETE FROM `#{config.SQL_TABLES.CHANNEL_LOGS}`
                WHERE `ChannelID`=#{@_toQuery(channelID)}
              "
        logsPromise = @_sendQuery(sql)

        # Delete channel joinings
        sql = "
                DELETE FROM `#{config.SQL_TABLES.CHANNEL_JOININGS}`
                WHERE `ChannelID`=#{@_toQuery(channelID)}
              "
        joinsPromise = @_sendQuery(sql)

        # Delete channels
        promise = Q.all([logsPromise, joinsPromise]).then =>
            sql = "
                    DELETE FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                    WHERE `ID`=#{@_toQuery(channelID)}
                  "
            return @_sendQuery(sql)

        return promise

    # Deletes all related data (logs, joinings, etc.) of all channels, which belong to the given game.
    # @param gameID [int] The id of the game world.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    deleteChannelsByGame: (gameID) ->
        internalGameChannel = "#{config.INTERN_GAME_CHANNEL_PREFIX}#{gameID}"

        # Delete channel logs
        sql = "
                DELETE FROM `#{config.SQL_TABLES.CHANNEL_LOGS}`
                WHERE `ChannelID` IN (
                    SELECT `ID` FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                    WHERE `GameID`=#{@_toQuery(gameID)}
                )
                OR `ChannelTextID`=#{@_toQuery(internalGameChannel)}
              "
        logsPromise = @_sendQuery(sql)

        # Delete channel joinings
        sql = "
                DELETE FROM `#{config.SQL_TABLES.CHANNEL_JOININGS}`
                WHERE `ChannelID` IN (
                    SELECT `ID` FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                    WHERE `GameID`=#{@_toQuery(gameID)}
                )
              "
        joinsPromise = @_sendQuery(sql)

        # Delete channels
        promise = Q.all([logsPromise, joinsPromise]).then =>
            sql = "
                    DELETE FROM `#{config.SQL_TABLES.CHANNEL_LIST}`
                    WHERE `GameID`=#{@_toQuery(gameID)}
                  "
            return @_sendQuery(sql)

        return promise

    # Saves the given client for having joined the given channel.
    # @param clientIdentity [ClientIdentity] The identity of the client.
    # @param channelName [string] The name of the channel.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    addClientToChannel: (clientIdentity, channelName) ->
        return unless channelName.indexOf(config.INTERN_NONGAME_CHANNEL_PREFIX) is 0  # Only non-game channels can be joined explicitly
        channelID = channelName.replace(config.INTERN_NONGAME_CHANNEL_PREFIX, '')
        userID = clientIdentity.getUserID()
        sql = "
                INSERT INTO `#{config.SQL_TABLES.CHANNEL_JOININGS}` SET
                    `UserID`=#{@_toQuery(userID)},
                    `ChannelID`=#{@_toQuery(channelID)}
              "
        return @_sendQuery(sql)

    # Deletes the given client from having joined the given channel.
    # @param clientIdentity [ClientIdentity] The identity of the client.
    # @param channelName [string] The name of the channel.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    removeClientFromChannel: (clientIdentity, channelName) ->
        return unless channelName.indexOf(config.INTERN_NONGAME_CHANNEL_PREFIX) is 0  # Only non-game channels can be parted explicitly
        channelID = channelName.replace(config.INTERN_NONGAME_CHANNEL_PREFIX, '')
        userID = clientIdentity.getUserID()
        sql = "
                DELETE FROM `#{config.SQL_TABLES.CHANNEL_JOININGS}`
                WHERE `UserID`=#{@_toQuery(userID)}
                  AND `ChannelID`=#{@_toQuery(channelID)}
              "
        return @_sendQuery(sql)



## Export class
module.exports = DefaultDatasource

