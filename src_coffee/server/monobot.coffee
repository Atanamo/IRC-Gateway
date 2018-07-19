
# Include app modules
Config = require './config'
AbstractBot = require './bot'


## Abstraction of an IRC bot, which is responsible for all game worlds at once
## and which therefor exists as singleton.
##
class MonoBot extends AbstractBot
    @_instance: null

    gamesMap: null

    constructor: (arg=null) ->
        return if arg?  # Ensure to not create a bot when gameData is passed-in

        @gamesMap = {};

        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, '')
        @userName = Config.BOT_USERNAME_PATTERN.replace(/<id>/i, '')
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, '')
        @realName = @realName.replace(/<name>/i, 'Multiverse')
        @realName = @realName.trim()

        # Create client instance
        super()

    @getInstance: ->
        unless @_instance?
            @_instance = new MonoBot()
        return @_instance

    # @override
    stop: (gameID) ->
        log.info "Removing bot '#{@nickName}' from channels of game ##{gameID}..."
        return @_disconnectFromChannels(
            disconnectServer: false
            filterGameID: gameID
        )

    # @override
    getID: ->
        return 'MONO_BOT'

    # @override
    getNickName: ->
        return @nickName

    # @override
    getDetailName: ->
        return ''

    #
    # Specific API of Mono-Bot
    #

    updateGamesList: (gamesList) ->
        # Convert list to map of id to title
        @gamesMap = gamesList.reduce((map, item) ->
            map[item.id or 'no_id'] = item.title or ''
            return map
        , {})


    #
    # BotChannel handling
    #

    # @override
    _getIrcMessageRepresentingWebClientUser: (senderIdentity, rawMessage) ->
        clientNick = senderIdentity.getName()
        gameID = senderIdentity.getGameID()
        gameTitle = @gamesMap[gameID]

        if gameTitle
            return "#{gameTitle}: <#{clientNick}> #{rawMessage}"
        else
            return super(senderIdentity, rawMessage)



# Export class
module.exports = MonoBot

