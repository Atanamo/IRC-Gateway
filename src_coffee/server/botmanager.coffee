
## Include app modules
Config = require './config'
BotChannel = require './botchannel'
Bot = require './bot'


## Main class
class BotManager
    isManaging: false
    watcherTimer: null

    botList: null
    globalChannel: null

    constructor: ->
        @botList = {}

    start: =>
        # Setup bot channels
        globalChannelPromise = @_setupGlobalBotChannel()
        singleChannelsPromise = @_setupSingleBotChannels()

        # Setup the bots
        botsPromise = @_setupBots()
        botsPromise = botsPromise.then =>
            return @_startBots(@botList)

        # After bots startup: Add them to their channels
        botsPromise.then =>
            log.info 'Bots have started, adding them to channels...'

            globalChannelPromise.then (globalChannel) =>
                @_addBotsToGlobalChannel(globalChannel, @botList)

            singleChannelsPromise.then (singleChannels) =>
                @_addBotsToSingleChannels(singleChannels, @botList)

            @_startGameWatcher()

        # End chain to observe errors
        botsPromise.done()

        return Q.all([globalChannelPromise, singleChannelsPromise])

    # Used by SocketHandler as callback to add a bot to a new channel 
    # (Therefor must be bound to BotManager instance)
    addGameBotToChannel: (gameID, channel) =>
        bot = @botList[gameID]
        return unless bot?
        return @_addBotToChannel(bot, channel)

    shutdown: =>
        clearInterval(@watcherTimer) if @watcherTimer?
        @_destroyBots(@botList)


    #
    # Initial setup routines
    #

    _setupBots: ->
        promise = db.getBotRepresentedGames()
        promise = promise.then (gamesList) =>
            for gameData in gamesList 
                # Create bot
                bot = new Bot(gameData)

                # Store bot by game id
                gameID = bot.getID()
                @botList[gameID] = bot

        return promise

    _setupGlobalBotChannel: ->
        promise = db.getGlobalChannelData()
        promise = promise.then (channelData) =>
            log.info 'Creating global channel...'
            @globalChannel = BotChannel.getInstance(channelData, true)
            return @globalChannel
        return promise

    _setupSingleBotChannels: ->
        promise = db.getSingleBotChannels()
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
        @watcherTimer = setInterval(intervalFunc, timerMilliSeconds)

    _manageBotsByGames: ->
        newBotsList = {}
        endBotsList = {}

        return if @isManaging
        @isManaging = true
        log.debug 'Starting managing bots...'

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
                    bot = new Bot(gameData)
                    newBotsList[gameID] = bot
                    @botList[gameID] = bot

                # Remove bot of existing game from end list
                delete endBotsList[gameID]
            return

        # Destroy bots to end
        promise = promise.then =>
            return @_destroyBots(endBotsList)

        # Start new bots
        promise = promise.then =>
            return @_startBots(newBotsList)

        # Join new bots to channels
        promise = promise.then =>
            @_addBotsToGlobalChannel(@globalChannel, newBotsList)
            @isManaging = false
            log.debug 'Finished managing bots!'

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

    _addBotsToSingleChannels: (singleChannels, botList) ->
        # For each channel, add its appropriate single bot to it
        for channel in singleChannels
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


    _destroyBots: (botList) ->
        promises = for gameID, bot of botList
            do (gameID, bot) =>
                destroy_promise = @_destroyBot(bot)
                destroy_promise.then =>
                    db.deleteChannelsByGame(gameID)
                return destroy_promise
        return Q.all(promises)

    _destroyBot: (bot) ->
        # Remove bot reference
        delete @botList[bot.getID()]

        # Remove bot from its channels (This is an optional soft shutdown action: Stopping the bot does the same on quit)
        promise = Q()
        #promise = @_removeBotFromChannels(bot)

        # Finally disconnect the bot
        promise = promise.then =>
            return bot.stop()

        return promise

    _removeBotFromChannels: (bot) ->
        channelList = bot.getWebChannelList()
        promises = for key, channel of channelList
            channel.removeBot(bot)
        return Q.all(promises)



## Export class
module.exports = BotManager

