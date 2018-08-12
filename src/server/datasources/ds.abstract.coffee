
## Include libraries
Q = require 'q'

## Include app modules
config = require '../config'

## Include abstract handler
AbstractDatabaseHandler = require '../databasehandlers/dbh.abstract'


## Abstraction of data managing methods:
## Wraps a database handler of choice.
## Provides ready-to-use methods for all needed read/write operations.
##
## Structure:
## * Database interface methods
## * Data value getters
## * Interface routines for app queries
##
class AbstractDatasource
    handler: null

    constructor: ->
        @handler = @_createHandler(config)

        unless @handler instanceof AbstractDatabaseHandler
            console.error('Database handler must be an instance of the AbstractDatabaseHandler class in file "dbh.abstract"!')

    _createHandler: (config) ->
        console.error('Database method "_createHandler" not implemented!')
        return null


    #
    # Database interface methods
    #

    connect: ->
        return @handler.connect()

    disconnect: ->
        return @handler.disconnect()

    _toQuery: (wildValue) ->
        return @handler.toQuery(wildValue)

    _sendQuery: (sqlQuery) ->
        return @handler.sendQuery(sqlQuery)

    _doTransaction: (transactionRoutineFunc) ->
        return @handler.doTransaction(transactionRoutineFunc)

    _readSimpleData: (sqlQuery, rejectIfEmpty=false) ->
        return @handler.readSimpleData(sqlQuery, rejectIfEmpty)

    _readMultipleData: (sqlQuery) ->
        return @handler.readMultipleData(sqlQuery)


    #
    # Data value getters
    #

    # Returns an error with given message and flagged as validation error.
    # @param error_msg [string] The error message.
    # @return [Error] An error object.
    createValidationError: (error_msg) ->
        err = new Error(error_msg)
        err.isValidation = true
        return err

    # Checks the given data for being valid to be passed to `createChannelByData()` and throws an error, if validation fails.
    # @param channelData [object] A data map with the channel data.
    # @throws Error if given data is invalid. The error is flagged as validation error.
    # @return [object] The validated and sanitized channel data.
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

        if config.REQUIRE_CHANNEL_PW and 2 >= channelData.password.length
            throw @createValidationError('Channel password too short')

        unless channelData.password.length <= 20
            throw @createValidationError('Channel password too long')

        return channelData


    #
    # Interface routines for app queries
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
        console.error('Database method "getClientIdentityData" not implemented!')
        return null

    # Returns the status information for each of the given list of game worlds.
    # This is used by a bot on request of one or more game statuses.
    # @param idList [array] An array of integers, each defining the id of a game world.
    # @return [promise] A promise, resolving to a list of data maps.
    #   Each data map must have at least the key `id` to reference the corresponding game world.
    #   The bot will output any further values of a data map as a game's status information.
    #   (The key of each of these values is used to label the value on output. Underscores are replaced by spaces.)
    #   The list may be empty, if none of the given games could be found.
    getGameStatuses: (idList=[]) ->
        console.error('Database method "getGameStatuses" not implemented!')
        return null

    # Returns the list of game worlds, which each have a bot to use for bot-channels.
    # If the mono-bot is configured, returns the list of all game worlds having a chat.
    # This list is also used to manage the lifetime of corresponding channels and its logs
    # by the game lookup interval.
    # @return [promise] A promise, resolving to a list of data maps, each having keys
    #   `id` (The unique id of the game world) and
    #   `title` (The display name of the game world - is allowed to contain spaces, etc.).
    #   The list may be empty, if there are no games at all.
    getBotRepresentedGames: ->
        console.error('Database method "getBotRepresentedGames" not implemented!')
        return null

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
        console.error('Database method "getGameBoundBotChannels" not implemented!')
        return null

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
        console.error('Database method "getChannelDataByTitle" not implemented!')
        return null

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
        console.error('Database method "getClientChannels" not implemented!')
        return null

    # Returns the number of channels, which were created by the given client.
    # @param clientIdentity [ClientIdentity] The identity of the client to count the channels for.
    # @return [promise] A promise, resolving to the number of channels.
    getClientCreatedChannelsCount: (clientIdentity) ->
        console.error('Database method "getClientCreatedChannelsCount" not implemented!')
        return null

    # Returns a list of messages/channel events, which had been logged for the given channel.
    # @param channelName [string] The internal name of the channel.
    # @return [promise] A promise, resolving to a list of data maps, each having keys
    #   `id` (The id of the list entry),
    #   `event_name` (The name of the logged channel event),
    #   `event_data` (The logged data for the event, serialized as JSON string - contains values like message text or sender identity) and
    #   `timestamp` (The timestamp of the log entry/event).
    #   The list may be empty, if no logs exists for the channel.
    getLoggedChannelMessages: (channelName) ->
        console.error('Database method "getLoggedChannelMessages" not implemented!')
        return null

    # Saves the given message/channel event to the channel logs. May replaces old logs.
    # @param channelName [string] The internal name of the channel.
    # @param timestamp [int] The timestamp of the event (in milliseconds).
    # @param eventName [string] The name of the channel event.
    # @param eventData [object] A data map, containing the main data for the event (like message text or sender identity).
    logChannelMessage: (channelName, timestamp, eventName, eventData) ->
        console.error('Database method "logChannelMessage" not implemented!')
        return null

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
        console.error('Database method "createChannelByData" not implemented!')
        return null

    # Deletes all related data (logs, joinings, etc.) of the channel with the given game.
    # @param channelName [string] The internal name of the channel to delete.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    deleteChannel: (channelName) ->
        console.error('Database method "deleteChannel" not implemented!')
        return null

    # Deletes all related data (logs, joinings, etc.) of all channels, which belong to the given game.
    # @param gameID [int] The id of the game world.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    deleteChannelsByGame: (gameID) ->
        console.error('Database method "deleteChannelsByGame" not implemented!')
        return null

    # Saves the given client for having joined the given channel.
    # @param clientIdentity [ClientIdentity] The identity of the client.
    # @param channelName [string] The name of the channel.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    addClientToChannel: (clientIdentity, channelName) ->
        console.error('Database method "addClientToChannel" not implemented!')
        return null

    # Deletes the given client from having joined the given channel.
    # @param clientIdentity [ClientIdentity] The identity of the client.
    # @param channelName [string] The name of the channel.
    # @return [promise] A promise to be resolved/rejected, when the operation has been finished or an error occured.
    removeClientFromChannel: (clientIdentity, channelName) ->
        console.error('Database method "removeClientFromChannel" not implemented!')
        return null



## Export class
module.exports = AbstractDatasource

