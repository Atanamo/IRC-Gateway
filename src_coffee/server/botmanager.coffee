
## Include libraries
Q = require 'q'

## Include app modules
log = require './logger'
db = require './database'

Config = require './config'
BotChannel = require './botchannel'
GameBot = require './gamebot'
MonoBot = require './monobot'


## Abstraction of a service for watching existence of games.
## It manages creation and destruction of bots based on the available games.
## To be used as singleton.
##
class BotManager
    isManaging: false
    hasBotPerGame: false
    watcherTimer: null

    botList: null
    globalChannel: null

    constructor: ->
        @hasBotPerGame = (Config.MAX_BOTS > 0)
        @botList = {}

    start: =>
        # Setup bot channels
        globalChannelPromise = @_setupGlobalBotChannel()
        globalChannelPromise.then (globalChannel) =>
            @globalChannel = globalChannel
        gameChannelsPromise = @_setupGameBoundBotChannels()

        # Setup the bots
        botsPromise = @_destroyBots(@botList)  # Guard call: Destroy any bots created before
        botsPromise = botsPromise.then =>
            if @hasBotPerGame
                return @_setupBots()
            else
                return @_setupMonoBot()
        botsPromise = botsPromise.then (botList) =>
            @botList = botList  # Set new list of bots
            return @_startBots(botList)

        # After bots startup: Add them to their channels
        botsPromise.then =>
            log.info 'Bots have started, adding them to channels...'

            globalChannelPromise.then (globalChannel) =>
                @_addBotsToGlobalChannel(globalChannel, @botList)

            gameChannelsPromise.then (gameChannels) =>
                @_addBotsToGameChannels(gameChannels, @botList)

            @_startGameWatcher()

        # End chain to observe errors
        botsPromise.done()

        return Q.all([globalChannelPromise, gameChannelsPromise])

    # Used by SocketHandler as callback to add a bot to a new channel
    # (Therefor must be bound to BotManager instance)
    addGameBotToChannel: (gameID, channel) =>
        bot = @botList[gameID]
        return unless bot?
        return @_addBotToChannel(bot, channel)

    shutdown: =>
        clearInterval(@watcherTimer) if @watcherTimer?
        promise = @_destroyBots(@botList)
        return promise


    #
    # Initial setup routines
    #

    _setupBots: ->
        promise = db.getBotRepresentedGames()
        promise = promise.then (gamesList) =>
            botList = {}

            for gameData in gamesList
                # Create bot
                bot = new GameBot(gameData)

                # Store bot by game id
                gameID = bot.getID()
                botList[gameID] = bot

            return botList

        return promise

    _setupMonoBot: ->
        # Create the bot
        bot = MonoBot.getInstance()

        # Store mono-bot by each game id
        promise = db.getBotRepresentedGames()
        promise = promise.then (gamesList) =>
            # Set initial list of games
            bot.updateGamesList(gamesList)

            # Store the bot for each game (makes handling easier)
            botList = {}
            for gameData in gamesList
                botList[gameData.id] = bot
            return botList

        return promise

    _setupGlobalBotChannel: ->
        promise = db.getGlobalChannelData()
        promise = promise.then (channelData) =>
            log.info 'Creating global channel...'
            return BotChannel.getInstance(channelData, true)
        return promise

    _setupGameBoundBotChannels: ->
        promise = db.getGameBoundBotChannels()
        promise = promise.then (channelList) =>
            log.info 'Creating additional bot channels...' if channelList?.length
            # Create every bot channel and push to result array
            channelInstances = []
            for channelData in channelList
                channel = BotChannel.getInstance(channelData)
                channelInstances.push(channel)
            return channelInstances
        return promise


    #
    # Watcher routine
    #

    _startGameWatcher: ->
        intervalFunc = =>
            @_manageBotsByGames()
        timerMilliSeconds = Config.GAMES_LOOKUP_INTERVAL * 1000
        clearInterval(@watcherTimer) if @watcherTimer?  # Clear old timer
        @watcherTimer = setInterval(intervalFunc, timerMilliSeconds) if timerMilliSeconds > 0

    _manageBotsByGames: ->
        newBotsList = {}
        endBotsList = {}

        return if @isManaging
        @isManaging = true
        log.debug 'Starting managing bots by games...'

        # Copy all old bots
        for key, bot of @botList
            endBotsList[key] = bot

        # Check games
        promise = db.getBotRepresentedGames()
        promise = promise.then (gamesList) =>
            for gameData in gamesList
                gameID = gameData.id

                # Create bot of new game
                unless @botList[gameID]?
                    bot =
                        if @hasBotPerGame
                            new GameBot(gameData)
                        else
                            MonoBot.getInstance()

                    newBotsList[gameID] = bot
                    @botList[gameID] = bot

                # Remove bot of existing game from end list
                delete endBotsList[gameID]

            # Only for mono-bot: Set list of games at once
            unless @hasBotPerGame
                bot = MonoBot.getInstance()
                bot.updateGamesList(gamesList)

            return

        # Destroy bots to end
        promise = promise.then =>
            return @_destroyBots(endBotsList, true)

        # Start new bots
        promise = promise.then =>
            return @_startBots(newBotsList)

        # Join new bots to channels
        promise = promise.then =>
            @_addBotsToGlobalChannel(@globalChannel, newBotsList) if @globalChannel
            @isManaging = false
            log.debug 'Finished managing bots by games!'

        # End chain to observe errors
        promise.done()


    #
    # Helpers
    #

    _startBots: (botList) ->
        startPromise = Q()

        for key, bot of botList
            # Encapsulate each iteration - for correct binding to promise callback
            do (bot) =>
                # Start bot as soon as previous bot has started (To avoid refuses by IRC server)
                startPromise = startPromise.then =>
                    return bot.start()

        return startPromise

    _addBotsToGlobalChannel: (globalChannel, botList) ->
        # Add every bot to channel
        joinPromise = Q()
        for key, bot of botList
            do (bot) =>
                # Join bot as soon as previous bot has joined (To have clean logging order)
                joinPromise = joinPromise.then =>
                    return @_addBotToChannel(bot, globalChannel)

    _addBotsToGameChannels: (gameChannels, botList) ->
        # For each channel, add its appropriate single bot to it
        for channel in gameChannels
            gameID = channel.getGameID()
            bot = botList[gameID]
            if bot?
                @_addBotToChannel(bot, channel)
            else
                log.warn "Could not find bot for game ##{gameID}", 'Bot channel creation'

    _addBotToChannel: (bot, channel) ->
        #connectPromise = bot.getConnectionPromise()
        #connectPromise.then =>
        return channel.addBot(bot)


    _destroyBots: (botList, deleteChannels=false) ->
        promises = for gameID, bot of botList
            do (gameID, bot) =>
                destroy_promise = @_destroyBot(bot, gameID)
                destroy_promise.then =>
                    db.deleteChannelsByGame(gameID) if deleteChannels
                return destroy_promise
        return Q.all(promises)

    _destroyBot: (bot, gameID) ->
        # Remove bot reference in main list
        delete @botList[gameID]

        # Remove bot from its channels (This is an optional soft shutdown action: Stopping the bot does the same on quit)
        promise = Q()

        # Finally disconnect the bot
        promise = promise.then =>
            return bot.stop(gameID)

        return promise



## Export class
module.exports = BotManager

