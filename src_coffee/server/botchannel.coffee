
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
            @_sendUserListToSocket(clientSocket)

    addBot: (bot) ->
        # Store bot reference, addressable by game id
        botID = bot.getID()
        @botList[botID] = bot

        # Let bot join the irc channel
        bot.handleWebChannelJoin(this)

    getIrcChannelName: ->
        return @ircChannelName

    getNumberOfClients: ->
        clientsMap = @_getUniqueClientsMap()
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

    _sendNoticeToRoom: (senderIdentity, noticeText) ->
        senderIdentData = senderIdentity.toData()
        @_sendToRoom 'notice',
            sender: senderIdentData
            text: noticeText

    _sendModeChangeToRoom: (actorIdentity, mode, isEnabled, modeArgument) ->
        actorIdentData = actorIdentity.toData()
        @_sendToRoom 'mode_change',
            actor: actorIdentData
            mode: mode
            enabled: isEnabled
            argument: modeArgument


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

    handleBotNotice: (senderNickName, noticeText) ->
        senderIdentity = ClientIdentity.createFromIrcNick(senderNickName)
        @_sendNoticeToRoom(senderIdentity, noticeText)

    handleBotTopicChange: (newTopic, authorNickName) ->
        @ircChannelTopic = newTopic
        @_sendChannelTopic(null, newTopic, authorNickName)  # Send topic to room

    handleBotChannelUserList: (nickMap) ->
        @ircUserList = nickMap
        @_sendUserListToRoom()


    handleBotChannelUserJoin: (nickName) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('add', 'join', userIdentity)

    handleBotChannelUserPart: (nickName, reasonText) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('remove', 'part', userIdentity, reason: reasonText)

    handleBotChannelUserQuit: (nickName, reasonText) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('remove', 'quit', userIdentity, reason: reasonText)

    handleBotChannelUserKick: (nickName, actorNickName, reasonText) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('remove', 'kick', userIdentity, {reason: reasonText, actor: actorNickName})

    handleBotChannelUserKill: (nickName, reasonText) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('remove', 'kill', userIdentity, reason: reasonText)

    handleBotChannelUserRename: (nickName, newNickName) ->
        userIdentity = ClientIdentity.createFromIrcNick(nickName)
        @_sendUserChangeToRoom('update', 'rename', userIdentity, newName: newNickName)


    #handleBotChannelUserModeUpdate: (nickName, actorNickName, mode, isEnabled) ->
    #    actorIdentity = ClientIdentity.createFromIrcNick(actorNickName)
    #    @_sendModeChangeToRoom(actorIdentity, mode, isEnabled, nickName)

    handleBotChannelModeUpdate: (actorNickName, mode, isEnabled, modeArgument) ->
        actorIdentity = ClientIdentity.createFromIrcNick(actorNickName)
        @_sendModeChangeToRoom(actorIdentity, mode, isEnabled, modeArgument)


    #
    # Helpers
    #

    # @override
    _getUserList: ->
        userList = super

        # Append irc users to list
        for nickName, userFlag of @ircUserList
            clientIdentity = ClientIdentity.createFromIrcNick("#{userFlag}#{nickName}")
            userList.push(clientIdentity.toData())

        return userList



## Export class
module.exports = BotChannel

