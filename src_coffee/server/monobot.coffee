
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


    #
    # Bot command routines
    #

    # @override
    _checkRespondForCustomBotCommand: (message, respondFunc, channelName) ->
        return (
            #@_checkRespondForGalaxiesOverview(message, respondFunc) or
            @_checkRespondForNumbersOfGalaxyClients(message, respondFunc, channelName)
        )

    # @override
    _checkRespondForHelp: (message, respondFunc) ->
        commandsList = [
                command: 'players?'
                description: 'How many players per galaxy are currently online (on the channel)?'
        ]
        super(message, respondFunc, commandsList)

    _checkRespondForNumbersOfGalaxyClients: (message, respondFunc, channelName=null) ->
        if message.indexOf('players?') > -1
            channelName = channelName or @_getGlobalBotChannelName()

            if channelName?
                botChannel = @botChannelList[channelName]
                answerLines = []

                for gameID in Object.keys(@gamesMap)
                    if botChannel.isGlobalChannel() or "#{botChannel.getGameID()}" is "#{gameID}"
                        clientsNum = botChannel.getNumberOfBotDependentClients(gameID)
                        gameTitle = @gamesMap[gameID] or "##{gameID}"
                        answerLines.push("#{gameTitle} = #{clientsNum}") if clientsNum > 0

                if answerLines.length > 0
                    infoLines = answerLines.join('\n')
                    respondFunc("Galaxy players in #{channelName}...\n#{infoLines}")
                else
                    respondFunc("Currently no players online in #{channelName}")

            else
                respondFunc("Cannot find channel to check galaxy players for!")
            return true
        return false



# Export class
module.exports = MonoBot

