
## Include libraries
Q = require 'q'

## Include app modules
log = require './logger'
Config = require './config'
Channel = require './channel'
BotChannel = require './botchannel'
ClientIdentity = require './clientidentity'
ClientFloodingRating = require './clientrating'


## Abstraction of a handler for common client request on a socket.io socket.
## Handles client connects/disconnects, auth requests and channel join/creation requests.
## Additional channel-specific requests are handled by Channel instances.
## To be used as singleton.
##
class SocketHandler

    constructor: (addGameBotToChannelCallback) ->
        @_addGameBotToChannel = addGameBotToChannelCallback

    start: (socketServer) ->
        @_bindSocketGlobalEvents(socketServer)

    _bindSocketGlobalEvents: (socketServer) ->
        # Register common websocket events
        socketServer.sockets.on 'connection', @_handleClientConnect  # Build-in event

    _bindSocketClientEvents: (clientSocket) ->
        # Store callback for disconnect on socket
        clientSocket.disconnectListener = =>
            @_handleClientDisconnect(clientSocket)

        # Register client socket events
        clientSocket.on 'disconnect', clientSocket.disconnectListener  # Build-in event
        clientSocket.on 'auth', (authData) => @_handleClientAuthRequest(clientSocket, authData)

    _bindSocketClientAuthorizedEvents: (clientSocket) ->
        clientSocket.on 'join', (channelData) => @_handleClientChannelJoin(clientSocket, channelData)

    _handleClientConnect: (clientSocket) =>
        log.debug 'Client connected...'
        # Add flooding rating object
        floodingCallback = =>
            @_handleClientFlooding(clientSocket)
        clientSocket.rating = new ClientFloodingRating(floodingCallback)
        clientSocket.rating.checkForFlooding(2)
        # Bind socket events to new client
        @_bindSocketClientEvents(clientSocket)

    _handleClientDisconnect: (clientSocket) =>
        return if clientSocket.isDisconnected
        log.debug 'Client disconnected...'
        clientSocket.isDisconnected = true
        # Deregister listeners
        clientSocket.removeListener 'disconnect', clientSocket.disconnectListener
        clientSocket.removeAllListeners 'auth'
        clientSocket.removeAllListeners 'join'

    _handleClientFlooding: (clientSocket) =>
        return if clientSocket.isDisconnected
        log.info "Disconnecting client '#{clientSocket.identity?.getName()}' due to flooding!"
        clientSocket.emit 'forced_disconnect', 'Recognized flooding attack'
        clientSocket.emit 'disconnect'
        clientSocket.disconnect(false)  # Disconnect without closing connection (avoids automatic reconnects)

    _handleClientAuthRequest: (clientSocket, authData) =>
        return unless clientSocket.rating.checkForFlooding((if clientSocket.hasTriedAuth then 14 else 1))
        return if clientSocket.identity?
        log.debug 'Client requests auth...'

        # Flag socket to have tried auth at least once
        clientSocket.hasTriedAuth = true

        # Set start values
        userID = authData.userID
        gameID = authData.gameID
        securityToken = authData.token

        authPromise = null

        # Check auth data
        if userID? and gameID?
            authPromise = ClientIdentity.createFromDatabase(userID, gameID)
            authPromise = authPromise.fail (err) =>
                throw db.createValidationError('Unknown user')  # Overwrite error
            authPromise = authPromise.then (clientIdentity) =>
                if Config.AUTH_ENABLED and securityToken isnt clientIdentity.securityToken
                    throw db.createValidationError('Invalid token')
                return clientIdentity
        else
            authPromise = Q.fcall =>
                throw db.createValidationError('Invalid user data')

        # Handle auth success/fail
        authPromise = authPromise.then (clientIdentity) =>
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
            return @_acceptNewClient(clientSocket)

        authPromise = authPromise.fail (err) =>
            throw err unless err.isValidation
            return if clientSocket.isDisconnected
            log.debug 'Client auth rejected:', err.message
            # Emit auth fail
            clientSocket.emit 'auth_fail', err.message

        # End chain to observe errors (non-validation-errors)
        authPromise.done()

    _acceptNewClient: (clientSocket) ->
        # Let client join to saved channels (and default channels)
        promise = db.getClientChannels(clientSocket.identity)
        promise.then (channelList) =>
            for channelData in channelList
                channel = Channel.getInstance(channelData)
                channel.addClient(clientSocket, true)
        promise = promise.fail (err) =>
            throw err unless err.isDatabaseResult
        return promise


    _handleClientChannelJoin: (clientSocket, channelData) =>
        return unless clientSocket.identity?
        return unless clientSocket.rating.checkForFlooding(7)

        gameID = clientSocket.identity.getGameID()
        requestedChannelTitle = channelData?.title or null
        requestedChannelPassword = channelData?.password or null

        return unless requestedChannelTitle?

        log.debug 'Client requests join for channel, data:', channelData

        # Check channel data
        promise = Q.fcall =>
            return if clientSocket.isDisconnected
            checkData =
                game_id: clientSocket.identity?.getGameID()
                title: channelData.title
                password: channelData.password
                is_public: channelData.isPublic
                is_for_irc: channelData.isForIrc
            return db.getValidatedChannelDataForCreation(checkData)

        # Check for existent channel
        promise = promise.then (validChannelData) =>
            channelData = validChannelData  # Overwrite in outer scope (for passing to fail handler)
            return db.getChannelDataByTitle(gameID, requestedChannelTitle)

        # Handle existing/non-existing channel
        promise = promise.fail (err) =>
            # Cancel channel creation, if error is not from existence check
            throw err unless err.isDatabaseResult
            throw err if clientSocket.isDisconnected
            # Channel does not exist yet, try creating it
            return @_createNewChannel(clientSocket.identity, channelData)

        promise = promise.then (existingChannelData) =>
            return if clientSocket.isDisconnected
            # Channel does (now) exist, try joining
            @_joinClientToChannel(clientSocket, existingChannelData, requestedChannelPassword)

        promise = promise.fail (err) =>
            return if err.isDatabaseResult
            throw err unless err.isValidation
            return if clientSocket.isDisconnected
            log.debug 'Client channel join rejected:', err.message
            # Emit join fail
            clientSocket.emit 'join_fail', err.message

        # End chain to observe errors (non-validation-errors)
        promise.done()

    _createNewChannel: (clientIdentity, channelData) ->
        # Check limit of created channels
        countPromise = db.getClientCreatedChannelsCount(clientIdentity)
        countPromise = countPromise.then (channelsCount) =>
            if channelsCount >= Config.MAX_CHANNELS_PER_CLIENT
                throw db.createValidationError('Reached channel limit')
            return true

        # If limit not reached, create the channel
        createPromise = countPromise.then =>
            log.debug 'Storing data for new channel:', channelData
            return db.createChannelByData(clientIdentity, channelData)

        return createPromise

    _joinClientToChannel: (clientSocket, channelData, requestedChannelPassword) ->
        # Check channel password
        if (requestedChannelPassword or '') isnt (channelData.password or '')
            throw db.createValidationError('Wrong password')

        # Get/create channel instance
        if channelData.irc_channel
            channel = BotChannel.getInstance(channelData)
            @_addGameBotToChannel(channelData.game_id, channel)
        else
            channel = Channel.getInstance(channelData)

        # Let client join the channel
        channel.addClient(clientSocket)



## Export class
module.exports = SocketHandler

