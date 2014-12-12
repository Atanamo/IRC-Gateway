
## Include app modules
Config = require './config'
BotChannel = require './botchannel'
Bot = require './bot'


## Main class
class BotManager

    botList: null

    constructor: ->
        @botList = {}

    start: ->
        setupPromise = @_setupBots()
        setupPromise = setupPromise.then =>
            return @_startBots()
        setupPromise = setupPromise.then =>
            return @_setupGlobalChannel()
        setupPromise = setupPromise.then =>
            return @_setupBotChannels()
        return setupPromise

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

    _setupGlobalChannel: ->
        promise = db.getGlobalChannelData()
        promise = promise.then (channelData) =>
            log.info 'Creating global channel...'
            channel = BotChannel.getInstance(channelData)
            # Add every bot to channel
            for key, bot of @botList
                @_addBotToChannel(bot, channel)
        return promise

    _setupBotChannels: ->
        promise = db.getSingleBotChannels()
        promise = promise.then (channelList) =>
            log.info 'Creating additional bot channels...' if channelList?.length

            # Create every bot channel and add the appropriate bot to it
            for channelData in channelList
                channel = BotChannel.getInstance(channelData)
                gameID = channel.getGameID()
                bot = @botList[gameID]

                if bot?
                    @_addBotToChannel(bot, channel)
                else
                    log.warn "Could not find bot for game ##{gameID}", 'Bot channel creation'

        return promise

    _startBots: ->
        startPromise = Q()

        for key, bot of @botList 
            # Encapsulate each iteration - for correct binding to promise callback
            do (bot) =>
                # Start bot as soon as previous bot has started (To avoid refuses by IRC server)
                startPromise = startPromise.then =>
                    return bot.start()

        return startPromise

    _addBotToChannel: (bot, channel) ->
        #connectPromise = bot.getConnectionPromise()
        #connectPromise.then =>
        channel.addBot(bot)

    _destroyBot: ->
        # TODO
        # - Iterate all BotChannels
        # - For each: channel.removeBot(bot)


## Export class
module.exports = BotManager

