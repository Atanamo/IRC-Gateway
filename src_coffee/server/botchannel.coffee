
## Include app modules
Config = require './config'
Channel = require './channel'
ClientIdentity = require './clientidentity'


## Extended abstraction of a socket.io room, which is mirrored to an IRC channel.
## Communication to IRC is handled by multiple Bots, each representing a game instance.
##
## When a socket client sends a message, it is routed to the bot, that represents the client's game instance.
## When a message is triggered on IRC, the respective bot sends it to the associated BotChannel.
## To prevent multiple triggers when having multiple bots, the channel specifies its first bot as master bot.
##
## @extends Channel
class BotChannel extends Channel
    @_instances: {}
    botList: null

    gameID: 0
    ircChannelName: ''
    ircChannelTopic: null
    ircUserList: null
    isPermanent: false

    constructor: (data, @isPermanent) ->
        super
        @ircChannelName = data.irc_channel or @ircChannelName
        @gameID = data.game_id or @gameID
        @botList = {}
        @ircUserList = {}

    # @override
    @getInstance: (channelData, isPermanent=false) ->
        name = channelData.name
        unless Channel._instances[name]?
            Channel._instances[name] = new BotChannel(channelData, isPermanent)
        return Channel._instances[name]

    # @override
    _checkForDestroy: ->
        if @_getNumberOfBots() is 0
            super unless @isPermanent

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
        isMasterBot = Object.keys(@botList).length is 1  # First bot is master
        joinPromise = bot.handleWebChannelJoin(this, isMasterBot)
        return joinPromise

    removeBot: (bot) ->
        botID = bot.getID()
        if @botList[botID]?
            # Remove bot reference before nominating new master
            delete @botList[botID]
            # Set next bot to be master
            if bot.isWebChannelMaster(this)
                for key, nextMasterBot of @botList
                    nextMasterBot.handleWebChannelMasterNomination(this)
                    break
            # Let bot part irc channel (This will be recognized by new master bot)
            partPromise = bot.handleWebChannelLeave(this)

            # May destroy instance (if it was the last bot)
            @_checkForDestroy()
            return partPromise
        return Q(false)

    getIrcChannelName: ->
        return @ircChannelName

    getGameID: ->
        return @gameID

    getNumberOfBotDependentClients: (botGameID) ->
        clientsMap = @_getUniqueClientsMap()
        clientsNum = 0
        for key, clientIdentity of clientsMap
            clientsNum++ if clientIdentity.getGameID() is botGameID
        return clientsNum

    _getNumberOfBots: ->
        return Object.keys(@botList).length


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
        log.debug "Client message to IRC (#{@ircChannelName}):", messageText
        botID = clientSocket.identity.getGameID() or -1
        targetBot = @botList[botID]
        return unless targetBot?

        # Send to IRC channel
        targetBot.handleWebClientMessage(@ircChannelName, clientSocket.identity, messageText)


    #
    # Bot handling
    #

    handleBotMessage: (senderNickName, messageText) ->
        # Try to find bot (if message has been sent by one) and set its game id for additional information to clients
        botGameID = null
        for botID, bot of @botList
            if bot.getNickName() is senderNickName.replace(/^[@+]/, '')
                botGameID = botID
        # Create sender identity and distribute message
        senderIdentity = ClientIdentity.createFromIrcNick(senderNickName, botGameID)
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

    handleBotQuit: (bot, reasonText) ->
        @removeBot(bot)
        if @_getNumberOfBots() is 0
            # Manually send quit notice, because no other bot can observe it
            @handleBotChannelUserQuit(bot.getNickName(), reasonText)
            @handleBotChannelUserList([])


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

