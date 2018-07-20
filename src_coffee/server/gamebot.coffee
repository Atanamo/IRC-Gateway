
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
    _checkRespondForCustomBotCommand: (message, respondFunc, channelName) ->
        return (
            @_checkRespondForGameName(message, respondFunc) or
            @_checkRespondForGameStatus(message, respondFunc) or
            @_checkRespondForGameRound(message, respondFunc) or
            @_checkRespondForNumberOfGameClients(message, respondFunc, channelName)
        )

    # @override
    _checkRespondForHelp: (message, respondFunc) ->
        commandsList = [
                command: 'game?'
                description: "What is the name of my #{Config.BOT_GAME_LABEL}?"
            ,
                command: 'status?'
                description: "What is the status of my #{Config.BOT_GAME_LABEL}?"
            ,
                command: 'round?'
                description: "How many rounds did my #{Config.BOT_GAME_LABEL} run yet?"
            ,
                command: 'ticks?'
                description: 'See "round?"'
            ,
                command: 'players?'
                description: "How many players of my #{Config.BOT_GAME_LABEL} are currently online (on the channel)?"
        ]
        super(message, respondFunc, commandsList)

    _checkRespondForGameName: (message, respondFunc) ->
        if message.indexOf('game?') > -1
            respondFunc("Name of #{Config.BOT_GAME_LABEL} = #{@gameData.title}")
            return true
        return false

    _checkRespondForGameStatus: (message, respondFunc) ->
        if message.indexOf('status?') > -1
            promise = db.getGameStatus(@gameData.id)
            promise.then (statusText) =>
                respondFunc("Status (#{@gameData.title}) = #{statusText}")
            return true
        return false

    _checkRespondForGameRound: (message, respondFunc) ->
        if message.indexOf('round?') > -1 or message.indexOf('ticks?') > -1
            promise = db.getGameRound(@gameData.id)
            promise.then (roundNum) =>
                respondFunc("Round (#{@gameData.title}) = #{roundNum}")
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

