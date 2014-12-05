
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
        authPromise = Q.fcall =>
            throw new Error('Invalid user data')

        # Check auth data
        if userID? and gameID?
            # TODO: Check authData.token or similar
            authPromise = ClientIdentity.createFromDatabase(userID, gameID)
            authPromise = authPromise.fail (err) =>
                throw new Error('Unknown user')  # Overwrite error

        # Handle auth success/fail
        authPromise.then (clientIdentity) =>
            log.debug 'Client auth granted'

            # Set client identification data
            clientSocket.identity = clientIdentity

            # Emit initial events for new client
            clientSocket.emit 'auth_ack'
            clientSocket.emit 'welcome', 'Hello out there!'

            # Add client to its channels
            @_acceptNewClient(clientSocket)

        authPromise.fail (err) =>
            log.debug 'Client auth rejected:', err.message
            # Emit auth fail
            clientSocket.emit 'auth_fail', err.message  # TODO: Send notice based on auth error


    _acceptNewClient: (clientSocket) ->
        # Let client join default channel
        botChannel = BotChannel.getInstance(Config.INTERN_BOT_CHANNEL_NAME, Config.IRC_CHANNEL_GLOBAL)  # TODO
        botChannel.addClient(clientSocket, true)

        # Let client join to saved channels
        channelList = db.getClientChannels(clientSocket.identity)

        for channelData in channelList
            channel = Channel.getInstance(channelData.name)
            channel.addClient(clientSocket, true)



## Export class
module.exports = SocketHandler

