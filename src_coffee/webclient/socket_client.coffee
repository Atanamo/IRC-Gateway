
# Controller class to handle communication with server
class this.SocketClient

    chatController: null
    socket: null

    serverIP: ''
    serverPort: 0
    instanceData: null
    identityData: null

    constructor: (@chatController, @serverIP, @serverPort, @instanceData) ->

    start: ->
        console.debug "Connecting to: #{@serverIP}:#{@serverPort}"

        @socket = io.connect("#{@serverIP}:#{@serverPort}")

        @socket.on 'connect', @_handleServerConnect         # Build-in event
        @socket.on 'disconnect', @_handleServerDisconnect   # Build-in event
        @socket.on 'error', @_handleServerDisconnect        # Build-in event

        @socket.on 'auth_ack', @_handleServerAuthAck
        @socket.on 'auth_fail', @_handleServerAuthFail
        @socket.on 'welcome', @_handleServerWelcome

        @socket.on 'history_start', @_handleChannelHistoryStart
        @socket.on 'history_end', @_handleChannelHistoryEnd
        @socket.on 'message', @_handleChannelMessage
        @socket.on 'notice', @_handleChannelNotice
        @socket.on 'joined', @_handleChannelJoined
        @socket.on 'left', @_handleChannelLeft
        @socket.on 'channel_topic', @_handleChannelTopic
        @socket.on 'channel_clients', @_handleChannelUserList
        @socket.on 'channel_clients_count', @_handleChannelUserNumber
        @socket.on 'user_change', @_handleChannelUserChange
        @socket.on 'mode_change', @_handleChannelModeChange


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @chatController.handleServerMessage('Connection established!')
        @chatController.handleServerMessage('Authenticating...')
        @_sendAuthRequest()

    _handleServerDisconnect: (errorMsg) =>
        @identityData = null
        if errorMsg?
            @chatController.handleServerMessage('Connection error: ' + errorMsg)
            console.error 'Connection error:', errorMsg
        else
            @chatController.handleServerMessage('Connection lost! Server may quit')
        @chatController.handleServerDisconnect()

    _handleServerAuthAck: (identityData) =>
        @identityData = identityData
        @chatController.handleServerMessage('Authentication successful!')

    _handleServerAuthFail: (errorMsg) =>
        @chatController.handleServerMessage('Authentication failed!')
        @chatController.handleServerMessage('Reason: ' + errorMsg)

    _handleServerWelcome: (text) =>
        @chatController.handleServerMessage('Welcome message: ' + text)


    _handleChannelJoined: (channel, timestamp, data) =>
        isOpeningJoin = @chatController.handleChannelJoined(channel, timestamp, data)
        @_sendChannelHistoryRequest(channel) if isOpeningJoin  # Only request history, if channel was not already opened

    _handleChannelLeft: (channel, timestamp) =>
        @chatController.handleChannelLeft(channel, timestamp)

    _handleChannelHistoryStart: (channel, timestamp, data) =>
        return if data.count is 0
        data.isStart = true
        @chatController.handleChannelHistoryMark(channel, timestamp, data)

    _handleChannelHistoryEnd: (channel, timestamp, data) =>
        return if data.count is 0
        data.isStart = false
        @chatController.handleChannelHistoryMark(channel, timestamp, data)

    _handleChannelTopic: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'author')
        @chatController.handleChannelTopic(channel, timestamp, data)

    _handleChannelUserList: (channel, timestamp, clientList) =>
        clientList = clientList.sort (firstData, secondData) =>
            firstName = firstData.name or firstData
            secondName = secondData.name or secondData
            return (firstName > secondName ? 1 : (firstName is secondName ? 0 : -1))
        @chatController.handleChannelUserList(channel, clientList)

    _handleChannelUserNumber: (channel, timestamp, clientsNumber) =>
        @chatController.handleChannelUserNumber(channel, clientsNumber)

    _handleChannelUserChange: (channel, timestamp, data) =>
        if not @_isOwnUser(data, 'user') or data.action in ['kick', 'kill']  # Ignore notices on own channel join/leave
            @_simplifyUserIdentityData(data, 'user')
            @_addContentMetaInfo(data, 'user')
            @chatController.handleChannelUserChange(channel, timestamp, data)

    _handleChannelModeChange: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'actor')
        @chatController.handleChannelModeChange(channel, timestamp, data)

    _handleChannelMessage: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data)
        @_addContentMetaInfo(data, 'text')
        @chatController.handleChannelMessage(channel, timestamp, data)

    _handleChannelNotice: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data)
        @_addContentMetaInfo(data, 'text')
        @chatController.handleChannelNotice(channel, timestamp, data)


    #
    # GUI commands / Sending routines
    #

    _sendAuthRequest: ->
        authData =
            userID: @instanceData.userID or 0
            gameID: @instanceData.gameID or 0
            token: @instanceData.token or ''
        @socket.emit 'auth', authData

    _sendChannelHistoryRequest: (channel) ->
        @socket.emit 'history#' + channel

    sendMessage: (channel, messageText) ->
        @socket.emit 'message#' + channel, messageText


    #
    # Helper methods
    #

    _simplifyUserIdentityData: (data, nameProperty='sender') ->
        data.isOwn = @_isOwnUser(data, nameProperty)
        data[nameProperty] = data[nameProperty]?.name or data[nameProperty]?.id  # Extract nick name from sender data

    _isOwnUser: (data, nameProperty='sender') ->
        ownIdentityData = @identityData or {}
        identData = data[nameProperty] or {}

        if identData.isIrcClient
            isFromOwnGame = (String(identData.idGame) == String(ownIdentityData.idGame))
            isFromOwnName = (String(data?.text).indexOf("<#{ownIdentityData.name}>") is 0)
            return (isFromOwnGame and isFromOwnName)

        return (String(identData.id) == String(ownIdentityData.id))

    _addContentMetaInfo: (data, addressTextProperty='text') ->
        unless data.isOwn
            data.isMentioningOwn = @_isAddressedToOwnUser(data[addressTextProperty], false)
            data.isAddressingOwn = @_isAddressedToOwnUser(data[addressTextProperty], true)

    _isAddressedToOwnUser: (addressText, onlyExplicitly) ->
        searchName = @identityData.name
        searchName = "((@#{searchName})|(#{searchName}:))" if onlyExplicitly  # Nick must be prefixed with "@" or postfixed with a colon
        searchRegex = new RegExp("(^|[^_a-z0-9])#{searchName}([^_a-z0-9]|$)", 'gim')

        return ((addressText.match(searchRegex)?.length or 0) isnt 0)



