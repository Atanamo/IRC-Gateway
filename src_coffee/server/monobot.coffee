
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
    _checkRespondForCustomBotCommand: (message, respondFunc, queryRespondFunc, channelName) ->
        return (
            @_checkRespondForGamesOverview(message, respondFunc, queryRespondFunc) or
            @_checkRespondForNumbersOfGameClients(message, respondFunc, queryRespondFunc, channelName)
        )

    # @override
    _checkRespondForHelp: (message, respondFunc) ->
        commandsList = [
                command: 'games?'
                description: "What is the status of each #{Config.BOT_GAME_LABEL} I represent?"
            ,
                command: 'status?'
                description: 'See "games?"'
            ,
                command: 'players?'
                description: "How many players per #{Config.BOT_GAME_LABEL} are currently online (on the channel)?"
        ]
        super(message, respondFunc, commandsList)

    _checkRespondForGamesOverview: (message, respondFunc, queryRespondFunc) ->
        if message.indexOf('games?') > -1 or message.indexOf('status?') > -1
            promise = db.getGameStatuses(Object.keys(@gamesMap))
            promise.then (gameStatusesList) =>
                if gameStatusesList.length > 0
                    gameLines = gameStatusesList.map (gameData) =>
                        gameTitle = @gamesMap[gameData.id] or "##{gameID}"
                        delete gameData.id

                        pairList = Object.keys(gameData).map (key) ->
                            title = key.trim().charAt(0).toUpperCase() + key.slice(1)
                            title = title.replace('_', ' ')
                            value = gameData[key]
                            return "[#{title}: #{value}]"
                        pairsString = pairList.join('  ')

                        return "#{gameTitle} =  #{pairsString}"

                    infoLines = gameLines.join('\n')

                    # Output to query, if too many lines
                    if gameLines.length > 3
                        queryRespondFunc("Status info per #{Config.BOT_GAME_LABEL}...\n#{infoLines}")
                    else
                        respondFunc("Status info per #{Config.BOT_GAME_LABEL}...\n#{infoLines}")

                else
                    respondFunc('Currently no game information available')

            return true
        return false

    _checkRespondForNumbersOfGameClients: (message, respondFunc, queryRespondFunc, channelName=null) ->
        if message.indexOf('players?') > -1
            channelName = channelName or @_getGlobalBotChannelName()

            if @botChannelList[channelName]?
                botChannel = @botChannelList[channelName]
                gameLines = []

                for gameID, gameTitle of @gamesMap
                    if botChannel.isGlobalChannel() or "#{botChannel.getGameID()}" is "#{gameID}"
                        clientsNum = botChannel.getNumberOfBotDependentClients(gameID)
                        gameTitle = @gamesMap[gameID] or "##{gameID}"
                        gameLines.push("#{gameTitle} = #{clientsNum}") if clientsNum > 0

                if gameLines.length > 0
                    infoLines = gameLines.join('\n')

                    # Output to query, if too many lines
                    if gameLines.length > 3
                        queryRespondFunc("Players per #{Config.BOT_GAME_LABEL} in #{channelName}...\n#{infoLines}")
                    else
                        respondFunc("Players per #{Config.BOT_GAME_LABEL} in #{channelName}...\n#{infoLines}")

                else
                    respondFunc("Currently no players online in #{channelName}")

            else
                respondFunc("Cannot find channel to check #{Config.BOT_GAME_LABEL} players for!")

            return true
        return false



# Export class
module.exports = MonoBot

