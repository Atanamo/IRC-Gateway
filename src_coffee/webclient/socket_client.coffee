
# Controller class to handle communication with server
class this.SocketClient

    chatController: null
    socket: null

    serverIP: ''
    serverPort: 0
    instanceData: {}
    identityData: {}

    constructor: (@chatController, @serverIP, @serverPort, @instanceData) ->

    start: ->
        console.debug "Connecting to: #{@serverIP}:#{@serverPort}"

        @socket = io.connect("#{@serverIP}:#{@serverPort}")

        @socket.on 'connect', @_handleServerConnect      # Build-in event
        @socket.on 'auth_ack', @_handleServerAuthAck
        @socket.on 'auth_fail', @_handleServerAuthFail
        @socket.on 'welcome', @_handleServerWelcome

        @socket.on 'message', @_handleChannelMessage
        @socket.on 'notice', @_handleChannelNotice
        @socket.on 'joined', @_handleChannelJoined
        @socket.on 'left', @_handleChannelLeft
        @socket.on 'channel_topic', @_handleChannelTopic
        @socket.on 'channel_clients', @_handleChannelUserList
        @socket.on 'user_change', @_handleChannelUserChange
        @socket.on 'mode_change', @_handleChannelModeChange


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @chatController.handleServerMessage('Connection established!')
        @chatController.handleServerMessage('Authenticating...')
        @_sendAuthRequest()

    _handleServerAuthAck: (identityData) =>
        @identityData = identityData
        @chatController.handleServerMessage('Authentication successful!')

    _handleServerAuthFail: (errorMsg) =>
        @chatController.handleServerMessage('Authentication failed!')
        @chatController.handleServerMessage('Reason: ' + errorMsg)

    _handleServerWelcome: (text) =>
        @chatController.handleServerMessage('Welcome message: ' + text)


    _handleChannelJoined: (channel, timestamp) =>
        @chatController.handleChannelJoined(channel, timestamp)

    _handleChannelLeft: (channel, timestamp) =>
        @chatController.handleChannelLeft(channel, timestamp)

    _handleChannelTopic: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'author')
        @chatController.handleChannelTopic(channel, timestamp, data)

    _handleChannelUserList: (channel, timestamp, clientList) =>
        @chatController.handleChannelUserList(channel, clientList)

    _handleChannelUserChange: (channel, timestamp, data) =>
        unless @_isOwnUser(data, 'user')  # Ignore notices on own channel join/leave
            @_simplifyUserIdentityData(data, 'user')
            @chatController.handleChannelUserChange(channel, timestamp, data)

    _handleChannelModeChange: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'actor')
        @chatController.handleChannelModeChange(channel, timestamp, data)

    _handleChannelMessage: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data)
        @chatController.handleChannelMessage(channel, timestamp, data)

    _handleChannelNotice: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data)
        @chatController.handleChannelNotice(channel, timestamp, data)


    #
    # GUI commands / Sending routines
    #

    sendMessage: (channel, messageText) ->
        @socket.emit 'message#' + channel, messageText

    _sendAuthRequest: ->
        authData =
            userID: @instanceData.userID or 0
            gameID: @instanceData.gameID or 0
            token: @instanceData.token or ''
        @socket.emit 'auth', authData


    #
    # Helper methods
    #

    _simplifyUserIdentityData: (data, nameProperty='sender') ->
        data.isOwn = @_isOwnUser(data, nameProperty)
        data[nameProperty] = data[nameProperty]?.name or data[nameProperty]?.id  # Extract nick name from sender data

    _isOwnUser: (data, nameProperty='sender') ->
        return (String(data[nameProperty]?.id) == String(@identityData.id))

