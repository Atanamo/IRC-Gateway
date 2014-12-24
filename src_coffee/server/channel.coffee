
## Include app modules
#Config = require './config'


## Basic abstraction of a socket.io room.
## If channel is public, it doesn't inform connected clients by a current list of other socket clients.
##
class Channel
    @_instances: {}

    uniqueClientsMap: null

    name: 'default'
    isPublic: false
    title: ''

    eventNameMsg: 'message#unnamed'
    eventNameLeave: 'leave#unnamed'


    constructor: (data) ->
        @_updateUniqueClientsMap()  # Initialize map of unique clients

        @name = data.name or @name
        @isPublic = data.is_public or @isPublic
        @title = data.title or @name

        log.debug "Creating new channel '#{@name}'"

        @eventNameMsg = 'message#' + @name
        @eventNameLeave = 'leave#' + @name

    @getInstance: (channelData) ->
        name = channelData.name
        unless @_instances[name]?
            @_instances[name] = new Channel(channelData)
        return @_instances[name]

    _destroy: ->
        log.debug "Destructing channel '#{@name}'"
        delete Channel._instances[@name]
        @uniqueClientsMap = null

    # May be overridden
    # @protected
    _checkForDestroy: ->
        if @getNumberOfClients() is 0
            @_destroy()


    #
    # Client management
    #

    getNumberOfClients: ->
        clientsMap = @_getUniqueClientsMap()
        return Object.keys(clientsMap).length

    _registerListeners: (clientSocket) ->
        clientSocket.on @eventNameMsg, (messageText) => @_handleClientMessage(clientSocket, messageText)
        clientSocket.on @eventNameLeave, => @_handleClientLeave(clientSocket)
        clientSocket.on 'disconnect', => @_handleClientLeave(clientSocket, true)

    addClient: (clientSocket, isRejoin=false) ->
        isExistingIdentity = @_hasUniqueClient(clientSocket)

        channelInfo =
            title: @title
            isPublic: @isPublic

        @_sendToSocket(clientSocket, 'joined', channelInfo)  # Notice client for channel join
        clientSocket.join(@name)                             # Join client to room of channel

        # Register events for this channel
        @_registerListeners(clientSocket)

        # Additional handling, if client's identity was not joined yet
        if not isExistingIdentity
            # Update the list of unique identities
            @_updateUniqueClientsMap()

            # Update visible users for channel (Send to all including client)
            if @isPublic
                @_sendUserNumberToRoom()
            else
                @_sendUserChangeToRoom('add', 'join', clientSocket.identity)
                @_sendUserListToRoom()

            # Permanently register client for channel
            unless isRejoin
                db.addClientToChannel(clientSocket, @name)
        else
            # Send initial user list to client
            if @isPublic
                @_sendUserNumberToSocket(clientSocket)
            else
                @_sendUserListToSocket(clientSocket)

    removeClient: (clientSocket, isDisconnect=false) ->
        # Unregister events for this channel
        clientSocket.removeAllListeners @eventNameMsg
        clientSocket.removeAllListeners @eventNameLeave
        clientSocket.removeAllListeners 'disconnect'

        # Update client
        clientSocket.leave(@name)             # Remove client from room of channel
        @_sendToSocket(clientSocket, 'left')  # Notice client for channel leave

        # Update the list of unique identities (May removes client's identity)
        @_updateUniqueClientsMap()

        # Additional handling, if client's identity is not joined any more
        unless @_hasUniqueClient(clientSocket)
            # Update visible users in channel
            if @isPublic
                @_sendUserNumberToRoom()
            else
                leaveAction = if isDisconnect then 'quit' else 'part'
                @_sendUserChangeToRoom('remove', leaveAction, clientSocket.identity)
                @_sendUserListToRoom()

            # Permanently unregister client for channel
            unless isDisconnect
                db.removeClientFromChannel(clientSocket, @name)

        # Remove and close instance, if last client left
        @_checkForDestroy()


    #
    # Sending routines
    #

    # @protected
    _sendToSocket: (clientSocket, eventName, data...) ->
        timestamp = @_getCurrentTimestamp()
        clientSocket.emit(eventName, @name, timestamp, data...)

    # @protected
    _sendUserList: (clientSocket) ->
        userList = @_getUserList()

        if clientSocket?
            @_sendToSocket(clientSocket, 'channel_clients', userList)
        else
            @_sendToRoom('channel_clients', userList)

    # @protected
    _sendUserListToSocket: (clientSocket) ->
        userList = @_getUserList()
        @_sendToSocket(clientSocket, 'channel_clients', userList)

    # @protected
    _sendUserNumberToSocket: (clientSocket) ->
        clientsNumber = @getNumberOfClients()
        @_sendToSocket(clientSocket, 'channel_clients_count', clientsNumber)


    # @protected
    _sendToRoom: (eventName, data...) ->
        timestamp = @_getCurrentTimestamp()
        io.sockets.in(@name).emit(eventName, @name, timestamp, data...)

    # @protected
    _sendUserListToRoom: ->
        userList = @_getUserList()
        @_sendToRoom('channel_clients', userList)

    # @protected
    _sendUserNumberToRoom: ->
        clientsNumber = @getNumberOfClients()
        @_sendToRoom('channel_clients_count', clientsNumber)

    # @protected
    _sendMessageToRoom: (senderIdentity, messageText) ->
        senderIdentData = senderIdentity.toData()
        @_sendToRoom 'message',
            sender: senderIdentData
            text: messageText

    # @protected
    _sendUserChangeToRoom: (type, action, userIdentity, additionalData) ->
        userIdentData = userIdentity.toData()
        @_sendToRoom 'user_change',
            type: type
            action: action
            user: userIdentData
            details: additionalData


    #
    # Client event handlers
    #

    # May be overridden
    # @protected
    _handleClientMessage: (clientSocket, messageText) =>
        log.debug 'Client message:', messageText
        messageText = messageText?.trim()
        return if messageText is ''
        @_sendMessageToRoom(clientSocket.identity, messageText)

    _handleClientLeave: (clientSocket, isDisconnect=false) =>
        log.debug "Removing client from channel '#{@name}' (by disconnect: #{isDisconnect}):", clientSocket.identity
        @removeClient(clientSocket, isDisconnect)


    #
    # Helpers
    #

    _getCurrentTimestamp: ->
        return (new Date()).getTime()

    _hasUniqueClient: (clientSocket) ->
        clientIdentity = clientSocket.identity
        clientsMap = @_getUniqueClientsMap()
        return clientsMap[clientIdentity.getGlobalID()]?

    _updateUniqueClientsMap: ->
        @uniqueClientsMap = @_getUniqueClientsMap(true)

    _getUniqueClientsMap: (forceUpdate=false) ->
        if forceUpdate
            #clientSocketList = io.sockets.clients(@name)  # Working till v0.9.x
            clientMetaList = io.sockets.adapter.rooms[@name]
            clientsMap = {}

            for clientID of clientMetaList
                clientSocket = io.sockets.connected[clientID]  # This is the socket of each client in the room

                if clientSocket?
                    clientIdentity = clientSocket.identity
                    clientsMap[clientIdentity.getGlobalID()] = clientIdentity if clientIdentity?
        else
            clientsMap = @uniqueClientsMap

        return clientsMap

    # May be overridden
    # @protected
    _getUserList: ->
        userList = []

        unless @isPublic
            clientsMap = @_getUniqueClientsMap()

            for clientID, clientIdentity of clientsMap
                userList.push(clientIdentity.toData())

        return userList




## Export class
module.exports = Channel

