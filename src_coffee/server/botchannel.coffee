
## Include app modules
Config = require './config'
Channel = require './channel'
ClientIdentity = require './clientidentity'


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
        botID = clientSocket.identity.getGameID() or -1
        targetBot = @_botList[botID]
        return unless targetBot?

        # Send to socket channel
        super

        # Send to IRC channel
        targetBot.handleWebClientMessage(clientSocket.identity, messageText)


    #
    # Bot handling
    #

    handleBotMessage: (senderNickName, messageText) ->
        senderIdentity = ClientIdentity.createFromIrcNick(senderNickName)

        @_sendMessageToRoom(senderIdentity, messageText)




## Export class
module.exports = BotChannel

