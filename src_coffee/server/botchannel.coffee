
## Include app modules
Config = require './config'
Channel = require './channel'
ClientIdentity = require './clientidentity'


## Extended abstraction of a socket.io room, which is mirrored to an IRC channel.
## Communication to IRC is handled by multiple Bots, each representing a game instance.
##
## When a socket client sends a message, it is routed to the bot, that represents the client's game instance.
## When a message is triggered on IRC, the respective bot sends it to the associated BotChannel.
##
## @extends Channel
class BotChannel extends Channel
    @_instances: {}
    botList: null

    ircChannelName: ''
    ircChannelTopic: null
    ircUserList: null

    constructor: (@name, @ircChannelName) ->
        super
        @botList = {}
        @ircUserList = {}

    # @override
    @getInstance: (name, ircChannelName) ->
        unless @_instances[name]?
            @_instances[name] = new BotChannel(name, ircChannelName)
        return @_instances[name]


    # @override
    addClient: (clientSocket, isRejoin=false) ->
        super(clientSocket, true)   # true, because: dont do that: db.addClientToChannel(clientSocket, @name)
        @_sendChannelTopic(clientSocket, @ircChannelTopic) if @ircChannelTopic?
        # Send list of irc users (if not already sent by super method)
        if @isPublic
            @_sendClientList(clientSocket)

    addBot: (bot) ->
        # Store bot reference, adressable by game id
        botID = bot.getID()
        @botList[botID] = bot

        # Let bot join the irc channel
        bot.handleWebChannelJoin(this)

    getIrcChannelName: ->
        return @ircChannelName

    getNumberOfClients: ->
        clientsMap = @_getUniqueClientsMap(true)
        return Object.keys(clientsMap).length


    #
    # Sending routines
    #

    _sendChannelTopic: (clientSocket, topicText, authorNickName) ->
        authorIdentity = ClientIdentity.createFromIrcNick(authorNickName) if authorNickName?
        data =
            topic: topicText
            author: authorIdentity
            isInitial: clientSocket?

        if clientSocket?
            @_sendToSocket(clientSocket, 'channel_topic', data)
        else
            @_sendToRoom('channel_topic', data)


    #
    # Client event handlers
    #

    # @override
    _handleClientMessage: (clientSocket, messageText) =>
        botID = clientSocket.identity.getGameID() or -1
        targetBot = @botList[botID]
        return unless targetBot?

        # Send to socket channel
        super

        # Send to IRC channel
        targetBot.handleWebClientMessage(@ircChannelName, clientSocket.identity, messageText)


    #
    # Bot handling
    #

    handleBotMessage: (senderNickName, messageText) ->
        senderIdentity = ClientIdentity.createFromIrcNick(senderNickName)
        @_sendMessageToRoom(senderIdentity, messageText)

    handleBotTopicChange: (newTopic, authorNickName) ->
        @ircChannelTopic = newTopic
        @_sendChannelTopic(null, newTopic, authorNickName)  # Send topic to room

    handleBotChannelUserList: (nickMap) ->
        @ircUserList = nickMap
        @_sendClientList()

    handleBotChannelUserChange: (changeType, reason, nickName, newNickName) ->
        # TODO: Handles changeType [ nick_rename, client_join, client_part ]
        # New client mode flags only relevant, if renaming


    #
    # Helpers
    #

    # @override
    _getUniqueClientsMap: (getOnlyWebClients=false) ->
        return super if getOnlyWebClients  # Don't filter non-public, don't append IRC users

        # Determine basic list
        if @isPublic
            clientsMap = {}
        else
            clientsMap = super
        # Append irc users to list
        for nickName, userFlag of @ircUserList
            clientsMap[nickName] = ClientIdentity.createFromIrcNick('' + userFlag + nickName)
        return clientsMap



## Export class
module.exports = BotChannel

