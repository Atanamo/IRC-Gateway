
## Include app modules
#Config = require './config'


## Basic abstraction of a socket.io room.
## If channel is public, it doesn't inform connected clients by a current list of other socket clients.
##
class Channel
    @_instances: {}

    name: 'default'
    isPublic: false
    title: 'New Channel'

    eventNameMsg: 'message#unnamed'
    eventNameLeave: 'leave#unnamed'


    constructor: (@name) ->
        log.info 'Creating new channel ' + @name

        data = db.getChannelData(@name)

        if data?
            @isPublic = data.is_public
            @title = data.title
            @eventNameMsg = 'message#' + @name
            @eventNameLeave = 'leave#' + @name

    @getInstance: (name) ->
        unless @_instances[name]?
            @_instances[name] = new Channel(name)
        return @_instances[name]


    #
    # Client management
    #

    addClient: (clientSocket, isRejoin=false) ->
        @_sendToSocket(clientSocket, 'joined')  # Notice client for channel join
        clientSocket.join(@name)                # Join client to room of channel

        # Register events for this channel
        clientSocket.on @eventNameMsg, (messageText) => @_handleClientMessage(clientSocket, messageText)
        clientSocket.on @eventNameLeave, => @_handleClientLeave(clientSocket)
        clientSocket.on 'disconnect', => @_handleClientLeave(clientSocket, true)

        # Update visible users in channel
        unless @isPublic
            @_sendToRoom 'client_joined',
                client: clientSocket.identity
            @_sendClientList(clientSocket)

        # Permanently register client for channel
        unless isRejoin
            db.addClientToChannel(clientSocket, @name)

    removeClient: (clientSocket, isDisconnect=false) ->
        # Unregister events for this channel
        clientSocket.removeAllListeners @eventNameMsg
        clientSocket.removeAllListeners @eventNameLeave
        clientSocket.removeAllListeners 'disconnect'

        # Update client
        clientSocket.leave(@name)             # Remove client from room of channel
        @_sendToSocket(clientSocket, 'left')  # Notice client for channel leave

        # Update visible users in channel
        unless @isPublic
            @_sendToRoom 'client_left',
                client: clientSocket.identity
            @_sendClientList(clientSocket)

        # Permanently unregister client for channel
        unless isDisconnect
            db.removeClientFromChannel(clientSocket, @name)


    #
    # Sending routines
    #

    # @protected
    _sendToSocket: (clientSocket, eventName, data...) ->
        timestamp = @_getCurrentTimestamp()
        clientSocket.emit(eventName, @name, timestamp, data...)

    # @protected
    _sendClientList: (clientSocket) ->
        clientList = []
        clientsMap = @_getUniqueClientsMap()

        for clientID, clientIdentity of clientsMap
            clientList.push(clientIdentity.toData())

        if clientSocket?
            @_sendToSocket(clientSocket, 'channel_clients', clientList)
        else
            @_sendToRoom('channel_clients', clientList)


    # @protected
    _sendToRoom: (eventName, data...) ->
        timestamp = @_getCurrentTimestamp()
        io.sockets.in(@name).emit(eventName, @name, timestamp, data...)

    # @protected
    _sendMessageToRoom: (senderIdentity, messageText) ->
        senderIdentData = senderIdentity.toData()
        @_sendToRoom 'message',
            sender: senderIdentData
            msg: messageText


    #
    # Client event handlers
    #

    # May be overridden
    # @protected
    _handleClientMessage: (clientSocket, messageText) =>
        log.info 'Client message:', messageText
        messageText = messageText?.trim()

        return if messageText is ''

        @_sendMessageToRoom(clientSocket.identity, messageText)


    _handleClientLeave: (clientSocket, isDisconnect=false) =>
        @removeClient(clientSocket, isDisconnect)


    #
    # Helpers
    #

    _getCurrentTimestamp: ->
        return (new Date()).getTime()

    # May be overridden
    # @protected
    _getUniqueClientsMap: ->
        #clientSocketList = io.sockets.clients(@name)  # Working till v0.9.x
        clientMetaList = io.sockets.adapter.rooms[@name]
        clientsMap = {}

        for clientID of clientMetaList
            clientSocket = io.sockets.connected[clientID]  # This is the socket of each client in the room

            if clientSocket?
                clientIdentity = clientSocket.identity
                clientsMap[clientIdentity.getGlobalID()] = clientIdentity if clientIdentity?

        return clientsMap




## Export class
module.exports = Channel

