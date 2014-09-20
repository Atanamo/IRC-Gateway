
## Include app modules
Config = require './config'
Channel = require './channel'


## Class definition
class BotChannel extends Channel
    @_instance: null
    _botList: null

    constructor: ->
        super
        @_botList = {}

    @getInstance: ->
        unless @_instance?
            @_instance = new BotChannel(Config.INTERN_BOT_CHANNEL_NAME)
            @_instances[@_instance.name] = @_instance
        return @_instance


    # @override
    addClient: (clientSocket, isRejoin=false) ->
        super(clientSocket, true)   # true, because: dont do that: db.addClientToChannel(clientSocket, @name)

    addBot: (bot) ->
        botID = bot.getID()
        @_botList[botID] = bot


    #
    # Sending routines
    #

    # @override
    _handleClientMessage: (clientSocket, messageText) =>
        botID = clientSocket.identData.game_id or -1
        targetBot = @_botList[botID]
        return unless targetBot?

        # Send to socket channel
        super

        # Send to IRC channel
        targetBot.handleWebClientMessage(clientSocket.identData, messageText)


    #
    # Bot handling
    #

    handleBotMessage: (sender, msg) ->
        




## Export class
module.exports = BotChannel

