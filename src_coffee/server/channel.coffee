
## Include app modules
Config = require './config'


## Class definition
class Channel
    @_instances: {}

    _isPublic = false
    _title = 'New Channel'
    _eventNameMsg = 'message#unnamed'
    _eventNameLeave = 'leave#unnamed'

    constructor: (@name) ->
        log.info 'Instance of new channel ' + @name

        data = db.getChannelData(@name)
        @_isPublic = data.is_public
        @_title = data.title
        @_eventNameMsg = 'message#' + @name
        @_eventNameLeave = 'leave#' + @name

    @getInstance: (name) ->
        unless @_instances[name]?
            @_instances[name] = new Channel(name)
        return @_instances[name]

    addClient: (clientSocket, isRejoin=false) ->
        clientSocket.emit 'joined', @name       # Notice client for channel join
        clientSocket.join(@name)                # Join client to room of channel

        # Register events for this channel
        clientSocket.on @_eventNameMsg, (messageText) => @_handleClientMessage(clientSocket, messageText)
        clientSocket.on @_eventNameLeave, => @_handleClientLeave(clientSocket)
        clientSocket.on 'disconnect', => @_handleClientLeave(clientSocket, true)

        # Update visible users in channel
        unless @_isPublic
            @_sendToRoom 'client_joined',
                channel: @name
                cldata: clientSocket.identData
            @_sendClientList(clientSocket)

        # Permanently register client for channel
        unless isRejoin
            db.addClientToChannel(clientSocket, @name)


    removeClient: (clientSocket, isDisconnect=false) ->
        # Unregister events for this channel
        clientSocket.removeAllListeners @_eventNameMsg
        clientSocket.removeAllListeners @_eventNameLeave
        clientSocket.removeAllListeners 'disconnect'

        # Update visible users in channel
        unless @_isPublic
            @_sendToRoom 'client_left',
                channel: @name
                client: clientSocket.identData.id

        clientSocket.leave(@name)               # Remove client from room of channel
        clientSocket.emit 'left', @name         # Notice client for channel leave

        # Permanently unregister client for channel
        unless isDisconnect
            db.removeClientFromChannel(clientSocket, @name)


    _sendClientList: (clientSocket) ->
        clientSocketList = io.sockets.clients(@name)
        #clientSocket.emit 'channel_clients', clientList
        ###
        console.info '----------------------------'
        console.info clientSocketList
        console.info '----------------------------'

        clientList = for socket in clientSocketList
            socket.id
        ###

    _sendToRoom: (eventName, data) ->
        io.sockets.in(@name).emit(eventName, data)


    _handleClientMessage: (clientSocket, messageText) =>
        log.info 'Client message:', messageText
        messageText = messageText?.trim()

        return unless messageText != ''

        @_sendToRoom 'message',
            channel: @name
            sender: clientSocket.identData.id
            msg: messageText


    _handleClientLeave: (clientSocket, isDisconnect=false) =>
        log.warn 'TODO: Client left'


## Export class
module.exports = Channel

