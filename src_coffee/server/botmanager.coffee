
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
        # Setup bot channels
        globalChannelPromise = @_setupGlobalBotChannel()
        singleChannelsPromise = @_setupSingleBotChannels()

        # Setup the bots
        botsPromise = @_setupBots()
        botsPromise = botsPromise.then =>
            return @_startBots()

        # After bots startup: Add them to their channels
        botsPromise.then =>
            log.info 'Bots have started, adding them to channels...'

            globalChannelPromise.then (globalChannel) =>
                @_addBotsToGlobalChannel(globalChannel, @botList)

            singleChannelsPromise.then (singleChannels) =>
                @_addBotsToSingleChannels(singleChannels, @botList)

        return Q.all([globalChannelPromise, singleChannelsPromise])


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

    _startBots: ->
        startPromise = Q()

        for key, bot of @botList 
            # Encapsulate each iteration - for correct binding to promise callback
            do (bot) =>
                # Start bot as soon as previous bot has started (To avoid refuses by IRC server)
                startPromise = startPromise.then =>
                    return bot.start()

        return startPromise


    _setupGlobalBotChannel: ->
        promise = db.getGlobalChannelData()
        promise = promise.then (channelData) =>
            log.info 'Creating global channel...'
            return BotChannel.getInstance(channelData)
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


    _destroyBot: ->
        # TODO
        # - Iterate all BotChannels
        # - For each: channel.removeBot(bot)


## Export class
module.exports = BotManager

