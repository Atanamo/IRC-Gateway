
# Include app modules
Config = require './config'
AbstractBot = require './bot'


## Abstraction of an IRC bot, which is responsible for one single game world.
##
class GameBot extends AbstractBot

    gameData: null

    constructor: (@gameData) ->
        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = Config.BOT_USERNAME_PATTERN.replace(/<id>/i, @gameData.id)
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.title)

        # Create client instance
        super()

    # @override
    getID: ->
        return @gameData.id

    # @override
    getNickName: ->
        return @nickName

    # @override
    getDetailName: ->
        return @gameData.title


    #
    # Bot command routines
    #

    # @override
    _checkRespondForCustomBotCommand: (message, respondFunc, queryRespondFunc, channelName) ->
        return (
            @_checkRespondForGameInfo(message, respondFunc) or
            @_checkRespondForNumberOfGameClients(message, respondFunc, channelName)
        )

    # @override
    _checkRespondForHelp: (message, respondFunc) ->
        commandsList = [
                command: 'game?'
                description: "What is the name and status of my #{Config.BOT_GAME_LABEL}?"
            ,
                command: 'status?'
                description: 'See "games?"'
            ,
                command: 'players?'
                description: "How many players of my #{Config.BOT_GAME_LABEL} are currently online (on the channel)?"
        ]
        super(message, respondFunc, commandsList)

    _checkRespondForGameInfo: (message, respondFunc) ->
        if message.indexOf('game?') > -1 or message.indexOf('status?') > -1
            promise = db.getGameStatuses([@gameData.id])
            promise.then (gameStatusesList) =>
                gameData = {}
                if gameStatusesList.length > 0
                    gameData = gameStatusesList[0]
                    delete gameData.id

                pairList = Object.keys(gameData).map (key) ->
                    title = key.trim().charAt(0).toUpperCase() + key.slice(1)
                    title = title.replace('_', ' ')
                    value = gameData[key]
                    return "#{title} = #{value}"
                pairList.unshift("Game = #{@gameData.title}")

                pairsString = pairList.join(';  ')
                respondFunc(pairsString)

            return true
        return false

    _checkRespondForNumberOfGameClients: (message, respondFunc, channelName=null) ->
        if message.indexOf('players?') > -1
            channelName = channelName or @_getGlobalBotChannelName()
            if channelName?
                botChannel = @botChannelList[channelName]
                clientsNum = botChannel.getNumberOfBotDependentClients(@gameData.id)
                respondFunc("Players of my #{Config.BOT_GAME_LABEL} in #{channelName} = #{clientsNum}")
            else
                respondFunc("Cannot find channel to check #{Config.BOT_GAME_LABEL} players for!")
            return true
        return false



# Export class
module.exports = GameBot

