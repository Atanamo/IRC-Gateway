
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

    _bindSocketClientAuthorizedEvents: (clientSocket) ->
        clientSocket.on 'join', (channelData) => @_handleClientChannelJoin(clientSocket, channelData)

    _handleClientConnect: (clientSocket) =>
        log.debug 'Client connected...'
        # Bind socket events to new client
        @_bindSocketClientEvents(clientSocket)

    _handleClientDisconnect: (clientSocket) =>
        log.debug 'Client disconnected...'
        # Deregister listeners
        clientSocket.isDisconnected = true
        clientSocket.removeAllListeners()
        #clientSocket.removeAllListeners 'disconnect'

    _handleClientAuthRequest: (clientSocket, authData) =>
        log.debug 'Client requests auth...'
        return if clientSocket.identity?

        userID = authData.userID
        gameID = authData.gameID
        securityToken = authData.token
        authPromise = Q.fcall =>
            throw new Error('Invalid user data')

        # Check auth data
        if userID? and gameID?
            authPromise = ClientIdentity.createFromDatabase(userID, gameID)
            authPromise = authPromise.fail (err) =>
                throw new Error('Unknown user')  # Overwrite error
            authPromise = authPromise.then (clientIdentity) =>
                if Config.AUTH_ENABLED and securityToken isnt clientIdentity.securityToken
                    throw new Error('Invalid token')
                return clientIdentity

        # Handle auth success/fail
        authPromise.then (clientIdentity) =>
            return if clientSocket.isDisconnected
            log.debug 'Client auth granted:', clientIdentity

            # Set client identification data
            clientSocket.identity = clientIdentity
            # Register additional events for client
            @_bindSocketClientAuthorizedEvents(clientSocket)

            # Emit initial events for new client
            clientSocket.emit 'auth_ack', clientIdentity.toData()
            clientSocket.emit 'welcome', "Hello #{clientIdentity.getName()}, you are now online!"

            # Add client to its channels
            @_acceptNewClient(clientSocket)

        authPromise.fail (err) =>
            return if clientSocket.isDisconnected
            log.debug 'Client auth rejected:', err.message
            # Emit auth fail
            clientSocket.emit 'auth_fail', err.message  # TODO: Send notice based on auth error

    _acceptNewClient: (clientSocket) ->
        # Let client join default channel
        #botChannel = BotChannel.getInstance(Config.INTERN_BOT_CHANNEL_NAME, Config.IRC_CHANNEL_GLOBAL)  # TODO
        #botChannel.addClient(clientSocket, true)

        # Let client join to saved channels
        promise = db.getClientChannels(clientSocket.identity)
        promise.then (channelList) =>
            #console.log 'LIST', channelList
            for channelData in channelList
                channel = Channel.getInstance(channelData)
                channel.addClient(clientSocket, true)


    _handleClientChannelJoin: (clientSocket, channelData) =>
        # TODO
        # - Check for channel existence in DB
        # - If it not exist, create it in DB
        # - Create/Get Channel instance
        # - Add client to channel instance
        # - If channel is a bot Channel: Add the bot of client's game


## Export class
module.exports = SocketHandler

