
## Include app modules
Config = require './config'


## Basic abstraction of a socket.io room.
## Instances have to be created by static method `getInstance()`:
## Each channel only is allowed to have one instance - meaning to have a singleton per channel name.
## An instance destroys itself after all clients have left.
##
## Messages to the channel (and other events) are broadcasted to all clients in the channel.
## Limitation on channels flagged public: Clients get not informed by a current list of other clients in the channel.
##
class Channel
    @_instances: {}

    uniqueClientsMap: null

    name: 'default'
    creatorID: 0
    title: ''
    isPublic: false
    isCustom: false

    eventNameMsg: 'message#unnamed'
    eventNameLeave: 'leave#unnamed'
    eventNameDelete: 'delete#unnamed'
    eventNameHistory: 'history#unnamed'
    listenerNameDisconnect: 'disconnectListener_unnamed'

    constructor: (data) ->
        @_updateUniqueClientsMap()  # Initialize map of unique clients

        @name = String(data.name or @name)
        @creatorID = data.creator_id or @creatorID
        @title = String(data.title or @name)
        @isPublic = data.is_public or @isPublic
        @isCustom = @name.indexOf(Config.INTERN_NONGAME_CHANNEL_PREFIX) is 0

        log.debug "Creating new channel '#{@name}'"

        @eventNameMsg = 'message#' + @name
        @eventNameLeave = 'leave#' + @name
        @eventNameDelete = 'delete#' + @name
        @eventNameHistory = 'history#' + @name
        @listenerNameDisconnect = 'disconnectListener_' + @name

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
            return true
        return false


    #
    # Client management
    #

    isCustomChannel: ->
        return @isCustom

    getNumberOfClients: ->
        clientsMap = @_getUniqueClientsMap()
        return Object.keys(clientsMap).length

    _registerListeners: (clientSocket) ->
        # Store callback for channel-specific disconnect on socket
        clientSocket[@listenerNameDisconnect] = disconnectCallback = =>
            @_handleClientDisconnect(clientSocket)

        # Register channel-specific client events
        clientSocket.on @eventNameMsg, (messageText) => @_handleClientMessage(clientSocket, messageText)
        clientSocket.on @eventNameLeave, (isClose) => @_handleClientLeave(clientSocket, isClose)
        clientSocket.on @eventNameDelete, => @_handleClientDeleteRequest(clientSocket)
        clientSocket.on @eventNameHistory, => @_handleClientHistoryRequest(clientSocket)
        clientSocket.on 'disconnect', disconnectCallback

    _unregisterListeners: (clientSocket) ->
        # Deregister listeners
        clientSocket.removeAllListeners @eventNameMsg
        clientSocket.removeAllListeners @eventNameLeave
        clientSocket.removeAllListeners @eventNameDelete
        clientSocket.removeAllListeners @eventNameHistory
        clientSocket.removeListener 'disconnect', clientSocket[@listenerNameDisconnect]

    addClient: (clientSocket, isRejoin=false) ->
        return false if @_hasJoinedSocket(clientSocket)  # Cancel, if socket is already joined to channel

        log.debug "Adding client '#{clientSocket.identity.getName()}' to channel '#{@name}'"

        isExistingIdentity = @_hasUniqueClient(clientSocket)

        channelInfo =
            title: @title
            creatorID: @creatorID
            isPublic: @isPublic
            isCustom: @isCustom
            ircChannelName: @ircChannelName  # Only available, when called from sub class BotChannel

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
                db.addClientToChannel(clientSocket.identity, @name)
        else
            # Send initial user list to client
            if @isPublic
                @_sendUserNumberToSocket(clientSocket)
            else
                @_sendUserListToSocket(clientSocket)

        return true

    removeClient: (clientSocket, isClose=false, isDisconnect=false) ->
        # Cancel, if socket is not joined to channel (but force on disconnect)
        return false if not isDisconnect and not @_hasJoinedSocket(clientSocket)

        log.debug "Removing client #{clientSocket.identity.getName()} from channel '#{@name}' (by close: #{isClose})"

        # Unregister events for this channel
        @_unregisterListeners(clientSocket)

        # Update client
        leaveInfo =
            title: @title
            isClose: isClose

        clientSocket.leave(@name)                        # Remove client from room of channel
        @_sendToSocket(clientSocket, 'left', leaveInfo)  # Notice client for channel leave

        # Update the list of unique identities (May removes client's identity)
        @_updateUniqueClientsMap()

        # Additional handling, if client's identity is not joined any more
        unless @_hasUniqueClient(clientSocket)
            # Update visible users in channel
            if @isPublic
                @_sendUserNumberToRoom()
            else
                leaveAction = if isDisconnect then 'quit' else (if isClose then 'close' else 'part')
                @_sendUserChangeToRoom('remove', leaveAction, clientSocket.identity)
                @_sendUserListToRoom()

            # Permanently unregister client from channel
            unless isClose
                db.removeClientFromChannel(clientSocket.identity, @name)

        # Remove and close instance, if last client left
        @_checkForDestroy()

        return true

    # @protected
    _deleteByClient: (clientSocket, customRoutine=null) ->
        return false unless @_hasJoinedSocket(clientSocket)  # Cancel, if socket is not joined to channel

        log.debug "Deleting channel '#{@name}' by client #{clientSocket.identity.getName()}"

        # Unregister events for this channel
        @_unregisterListeners(clientSocket)

        # Inform clients (There may be multiple sockets, but only one identity)
        deleteInfo =
            title: @title

        @_sendToRoom('deleted', deleteInfo, false)

        # Kick all sockets out of room
        @_iterateEachJoinedSocket (currClientSocket) =>
            @_unregisterListeners(currClientSocket)
            currClientSocket.leave(@name)

        # Update the list of unique identities (Should now be empty)
        @_updateUniqueClientsMap()

        # Optionally run custom routine (For child classes)
        customRoutine?()

        # Remove and close instance, if last client left
        is_destroyed = @_checkForDestroy()

        # Delete channel from database (For security, only delete, if channel has been destroyed)
        if is_destroyed
            db.deleteChannel(@name)

        return true


    #
    # Sending routines
    #

    # @protected
    _sendToSocket: (clientSocket, eventName, data...) ->
        timestamp = @_getCurrentTimestamp()
        clientSocket.emit(eventName, @name, timestamp, data...)

    # @protected
    _sendHistoryToSocket: (clientSocket) ->
        promise = db.getLoggedChannelMessages(@name)
        promise.then (logListData) =>
            oldestTimestamp = logListData[0]?.timestamp or -1
            newestTimestamp = logListData[logListData.length - 1]?.timestamp or -1

            # Filter last entry, if it's the client's join (Cause in this case, the history is requested on joining)
            if not @isPublic
                lastEntry = logListData[logListData.length-1]
                if lastEntry?.event_name is 'user_change'
                    eventData = JSON.parse(lastEntry.event_data) or {}
                    logListData.pop() if eventData.type is 'add' or  eventData.action is 'join'

            # Build marker data
            markerData =
                count: logListData.length
                start: oldestTimestamp
                end: newestTimestamp

            # Send history
            @_sendToSocket(clientSocket, 'history_start', markerData)
            for logEntry in logListData
                eventData = JSON.parse(logEntry.event_data)
                clientSocket.emit(logEntry.event_name, @name, logEntry.timestamp, eventData)  # Emit logged event as if it just occured
            @_sendToSocket(clientSocket, 'history_end', markerData)

    # @protected
    _sendUserListToSocket: (clientSocket) ->
        userList = @_getUserList()
        @_sendToSocket(clientSocket, 'channel_clients', userList)

    # @protected
    _sendUserNumberToSocket: (clientSocket) ->
        clientsNumber = @getNumberOfClients()
        @_sendToSocket(clientSocket, 'channel_clients_count', clientsNumber)


    # @protected
    _sendToRoom: (eventName, eventData, logToDatabase=true) ->
        timestamp = @_getCurrentTimestamp()
        io.sockets.in(@name).emit(eventName, @name, timestamp, eventData)
        if logToDatabase
            db.logChannelMessage(@name, timestamp, eventName, eventData)

    # @protected
    _sendUserListToRoom: ->
        userList = @_getUserList()
        @_sendToRoom('channel_clients', userList, false)

    # @protected
    _sendUserNumberToRoom: ->
        clientsNumber = @getNumberOfClients()
        @_sendToRoom('channel_clients_count', clientsNumber, false)

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
    _handleClientMessage: (clientSocket, messageText) ->
        return unless clientSocket.rating.checkForFlooding(8)
        log.debug "Client message to '#{@name}':", messageText
        messageText = messageText?.trim() or ''
        return if messageText is ''
        @_sendMessageToRoom(clientSocket.identity, messageText)

    _handleClientHistoryRequest: (clientSocket) =>
        flagName = 'hasHistory_' + @name
        return unless clientSocket.rating.checkForFlooding((if clientSocket[flagName] then 10 else 1))
        log.debug "Client requests chat history for '#{@name}'"
        clientSocket[flagName] = true  # Flag socket to have requested history at least once
        @_sendHistoryToSocket(clientSocket)

    _handleClientLeave: (clientSocket, isClose=false) ->
        return unless clientSocket.rating.checkForFlooding(3)
        if not isClose and clientSocket.identity.getUserID() is @creatorID
            # Disallow permanent leaving on channels created by the client
            @_sendToSocket(clientSocket, 'leave_fail', 'Cannot leave own channels')
        else
            @removeClient(clientSocket, isClose)

    _handleClientDisconnect: (clientSocket) ->
        # Immediately unregister listeners
        @_unregisterListeners(clientSocket)
        # Delay disconnect for configured time - This will allow to rejoin before disconnect is executed
        delay_promise = Q.delay(Config.CLIENTS_DISCONNECT_DELAY)
        delay_promise = delay_promise.then =>
            @removeClient(clientSocket, true, true)
        delay_promise.done()

    _handleClientDeleteRequest: (clientSocket) ->
        return unless clientSocket.rating.checkForFlooding(4)
        if clientSocket.identity.getUserID() isnt @creatorID
            @_sendToSocket(clientSocket, 'delete_fail', 'Can only delete own channels')
        else if @getNumberOfClients() > 1
            @_sendToSocket(clientSocket, 'delete_fail', 'Can only delete empty channels')
        else
            @_deleteByClient(clientSocket)


    #
    # Helpers
    #

    _getCurrentTimestamp: ->
        return (new Date()).getTime()

    _hasJoinedSocket: (clientSocket) ->
        #return clientSocket.rooms.indexOf(@name) >= 0  # Working till v1.3.x, then rooms changed to a map
        return clientSocket.rooms[@name]?

    _hasUniqueClient: (clientSocket) ->
        clientIdentity = clientSocket.identity
        clientsMap = @_getUniqueClientsMap()
        return clientsMap[clientIdentity.getGlobalID()]?

    _updateUniqueClientsMap: ->
        @uniqueClientsMap = @_getUniqueClientsMap(true)

    _getUniqueClientsMap: (forceUpdate=false) ->
        if forceUpdate
            clientsMap = {}
            @_iterateEachJoinedSocket (clientSocket) =>
                clientIdentity = clientSocket.identity
                clientsMap[clientIdentity.getGlobalID()] = clientIdentity if clientIdentity?
        else
            clientsMap = @uniqueClientsMap or {}

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

    _iterateEachJoinedSocket: (iterationCallback) ->
        #clientSocketList = io.sockets.clients(@name)  # Working till v0.9.x
        clientMetaList = io.sockets.adapter.rooms[@name]
        clientMetaList = clientMetaList?.sockets or clientMetaList or {}  # There's no sockets property till v0.3.x

        for clientID of clientMetaList
            clientSocket = io.sockets.connected[clientID]  # This is the socket of each client in the room

            # Call back on every real socket
            iterationCallback(clientSocket) if clientSocket?



## Export class
module.exports = Channel

