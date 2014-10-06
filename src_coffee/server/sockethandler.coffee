
# Include libraries
socketio = require 'socket.io'

## Include app modules
Config = require './config'
ClientIdentity = require './clientidentity'
Channel = require './channel'
BotChannel = require './botchannel'


## Main class
class SocketHandler

    constructor: ->

    start: ->
        @_bindSocketGlobalEvents()


    _bindSocketGlobalEvents: ->
        ## Register common websocket events
        io.sockets.on 'connection', @_handleClientConnect  # Build-in event

    _bindSocketClientEvents: (clientSocket) ->
        ## Register client socket events
        clientSocket.on 'disconnect', => @_handleClientDisconnect(clientSocket)  # Build-in event
        clientSocket.on 'auth', (authData) => @_handleClientAuthRequest(clientSocket, authData)


    _handleClientConnect: (clientSocket) =>
        log.debug 'Client connected...'
        # Bind socket events to new client
        @_bindSocketClientEvents(clientSocket)

    _handleClientDisconnect: (clientSocket) =>
        log.debug 'Client disconnected...'
        # Deregister listeners
        clientSocket.removeAllListeners 'disconnect'

    _handleClientAuthRequest: (clientSocket, authData) =>
        log.debug 'Client requests auth...'
        return if clientSocket.identity?

        userID = authData.id
        gameID = authData.game_id
        isAuthenticated = false

        # Check auth data
        if userID? and gameID?
            # TODO
            clientIdentity = ClientIdentity.createFromDatabase(userID, gameID)
            isAuthenticated = clientIdentity?  # TODO: Check authData.token or similar

        # Handle auth success/fail
        if isAuthenticated
            # Set client identification data
            clientSocket.identity = clientIdentity

            # Emit initial events for new client
            clientSocket.emit 'auth_ack'
            clientSocket.emit 'welcome', 'Hello out there!'

            # Add client to its channels
            @_acceptNewClient(clientSocket)

        else
            # Emit auth fail
            clientSocket.emit 'auth_fail', 'Invalid user data'  # TODO: Send notice based on auth error


    _acceptNewClient: (clientSocket) ->
        # Let client join default channel
        botChannel = BotChannel.getInstance(Config.INTERN_BOT_CHANNEL_NAME, Config.IRC_CHANNEL_GLOBAL)  # TODO
        botChannel.addClient(clientSocket, true)

        # Let client join to saved channels
        channelList = db.getClientChannels(clientSocket)

        for channelData in channelList
            channel = Channel.getInstance(channelData.name)
            channel.addClient(clientSocket, true)



## Export class
module.exports = SocketHandler

