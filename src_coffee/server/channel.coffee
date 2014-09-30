
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
        clientSocket.emit 'joined', @name       # Notice client for channel join
        clientSocket.join(@name)                # Join client to room of channel

        # Register events for this channel
        clientSocket.on @eventNameMsg, (messageText) => @_handleClientMessage(clientSocket, messageText)
        clientSocket.on @eventNameLeave, => @_handleClientLeave(clientSocket)
        clientSocket.on 'disconnect', => @_handleClientLeave(clientSocket, true)

        # Update visible users in channel
        unless @isPublic
            @_sendToRoom 'client_joined',
                channel: @name
                cldata: clientSocket.identity
            @_sendClientList(clientSocket)

        # Permanently register client for channel
        unless isRejoin
            db.addClientToChannel(clientSocket, @name)

    removeClient: (clientSocket, isDisconnect=false) ->
        # Unregister events for this channel
        clientSocket.removeAllListeners @eventNameMsg
        clientSocket.removeAllListeners @eventNameLeave
        clientSocket.removeAllListeners 'disconnect'

        # Update visible users in channel
        unless @_isPublic
            @_sendToRoom 'client_left',
                channel: @name
                client: clientSocket.identity

        clientSocket.leave(@name)               # Remove client from room of channel
        clientSocket.emit 'left', @name         # Notice client for channel leave

        # Permanently unregister client for channel
        unless isDisconnect
            db.removeClientFromChannel(clientSocket, @name)


    #
    # Sending routines
    #

    # @protected
    _sendToSocket: (clientSocket, eventName, data...) ->
        clientSocket.emit(eventName, @name, data...)

    _sendClientList: (clientSocket) ->
        #clientSocketList = io.sockets.clients(@name)  # Working till v0.9.x
        clientMetaList = io.sockets.adapter.rooms[@name]
        clientList = []

        for clientID of clientMetaList
            clientSocket = io.sockets.connected[clientID]  # This is the socket of each client in the room

            if clientSocket?
                clientIdentData = clientSocket.identity?.toData()
                clientList.push(clientIdentData)

            # you can do whatever you need with this
            #clientSocket.emit('new event', "Updates")

        @_sendToSocket(clientSocket, 'channel_clients', clientList)


    # @protected
    _sendToRoom: (eventName, data...) ->
        io.sockets.in(@name).emit(eventName, data...)

    # @protected
    _sendMessageToRoom: (senderIdentity, messageText) ->
        senderIdentData = senderIdentity.toData()
        @_sendToRoom 'message',
            channel: @name
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



## Export class
module.exports = Channel

