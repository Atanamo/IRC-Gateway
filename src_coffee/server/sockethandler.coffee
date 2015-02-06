
# Include libraries
socketio = require 'socket.io'

## Include app modules
Config = require './config'
ClientIdentity = require './clientidentity'
Channel = require './channel'
BotChannel = require './botchannel'


## Main class
class SocketHandler

    constructor: (addGameBotToChannelCallback) ->
        @_addGameBotToChannel = addGameBotToChannelCallback

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
        # Let client join to saved channels (and default channels)
        promise = db.getClientChannels(clientSocket.identity)
        promise.then (channelList) =>
            for channelData in channelList
                channel = Channel.getInstance(channelData)
                channel.addClient(clientSocket, true)


    _handleClientChannelJoin: (clientSocket, channelData) =>
        # TODO
        # + Check for channel existence in DB
        # + If it not exist, create it in DB
        # + Create/Get Channel instance
        # + Add client to channel instance (if it is not already in it)
        # + If channel is a bot Channel: Add the bot of client's game
        # - Check password for channel
        return unless clientSocket.identity?

        gameID = clientSocket.identity.getGameID()
        requestedChannelTitle = channelData?.title or null
        requestedChannelPassword = channelData?.password or null

        return unless requestedChannelTitle?

        log.debug 'Client requests join for channel, data:', channelData

        # Check for existent channel
        promise = db.getChannelDataByTitle(gameID, requestedChannelTitle)

        # Handle existing/non-existing channel
        promise = promise.fail (err) =>
            # Channel does not exist yet, create it
            createData =
                game_id: gameID
                title: channelData.title
                password: channelData.password
                is_public: channelData.isPublic or false
                is_for_irc: channelData.isForIrc or false
            return db.createChannelByData(createData)

        promise = promise.then (channelData) =>
            if (requestedChannelPassword or '') isnt (channelData.password or '')
                throw new Error('Wrong password')

            # Channel does exist, get/create instance
            if channelData.irc_channel
                channel = BotChannel.getInstance(channelData)
                @_addGameBotToChannel(gameID, channel)
            else
                channel = Channel.getInstance(channelData)

            # Let client join the channel
            channel.addClient(clientSocket)

        promise.fail (err) =>
            # Emit join fail
            clientSocket.emit 'join_fail', err.message  
            # In webclient: Translate errors by creating keys from messages (all lower case, spaces replaced);
            #               fallback to original message, if translation cannot be found



## Export class
module.exports = SocketHandler

