
# Controller class to handle communication with server
class this.SocketClient

    chatController: null
    socket: null

    serverIP: ''
    serverPort: 0
    instanceData: null
    identityData: null
    lastMessageSentStamp: 0
    isDisonnected: true

    constructor: (@chatController, @serverIP, @serverPort, @instanceData) ->

    start: ->
        console.debug "Connecting to: #{@serverIP}:#{@serverPort}"

        @socket = io.connect("#{@serverIP}:#{@serverPort}", reconnectionDelay: 5000)

        @socket.on 'connect', @_handleServerConnect         # Build-in event
        @socket.on 'connect_error', @_handleServerConnectError      # Build-in event
        @socket.on 'connect_timeout', @_handleServerConnectTimeout  # Build-in event
        @socket.on 'disconnect', @_handleServerDisconnect   # Build-in event
        @socket.on 'error', @_handleServerDisconnect        # Build-in event
        @socket.on 'forced_disconnect', @_handleServerDisconnect

        @socket.on 'auth_ack', @_handleServerAuthAck
        @socket.on 'auth_fail', @_handleServerAuthFail
        @socket.on 'welcome', @_handleServerWelcome

        @socket.on 'join_fail', @_handleChannelJoinFail
        @socket.on 'leave_fail', @_handleChannelLeaveFail
        @socket.on 'delete_fail', @_handleChannelDeleteFail
        @socket.on 'joined', @_handleChannelJoined
        @socket.on 'left', @_handleChannelLeft
        @socket.on 'deleted', @_handleChannelDeleted

        @socket.on 'history_start', @_handleChannelHistoryStart
        @socket.on 'history_end', @_handleChannelHistoryEnd
        @socket.on 'message', @_handleChannelMessage
        @socket.on 'notice', @_handleChannelNotice
        @socket.on 'channel_topic', @_handleChannelTopic
        @socket.on 'channel_clients', @_handleChannelUserList
        @socket.on 'channel_clients_count', @_handleChannelUserNumber
        @socket.on 'user_change', @_handleChannelUserChange
        @socket.on 'mode_change', @_handleChannelModeChange


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @isDisonnected = false
        @chatController.handleServerMessage(Translation.get('manage_msg.connect_success'))
        @chatController.handleServerMessage(Translation.get('manage_msg.auth_start'))
        @_sendAuthRequest()

    _handleServerConnectError: (errorObj) =>
        errorObj ?= message: 'Unknown connect error'
        console.error 'Connecting error:', "'#{errorObj.message}'", (errorObj.type or '')

    _handleServerConnectTimeout: (errorObj) =>
        errorObj ?= message: 'Timeout!'
        @_handleServerConnectError(errorObj)

    _handleServerDisconnect: (errorMsg) =>
        return if @isDisonnected
        @isDisonnected = true
        @identityData = null
        if errorMsg?
            serverText = Translation.getForServerMessage(errorMsg)
            text = Translation.get('manage_msg.connect_error', error: serverText)
            @chatController.handleServerMessage(text, true)
            console.error 'Connection error:', errorMsg
        else
            @chatController.handleServerMessage(Translation.get('manage_msg.connect_lost'), true)
        @chatController.handleServerDisconnect()

    _handleServerAuthAck: (identityData) =>
        @identityData = identityData
        @chatController.handleServerMessage(Translation.get('manage_msg.auth_success'))

    _handleServerAuthFail: (errorMsg) =>
        serverText = Translation.getForServerMessage(errorMsg)
        text = Translation.get('manage_msg.auth_failed', reason: serverText)
        @chatController.handleServerMessage(text, true)

    _handleServerWelcome: (welcomeMsg) =>
        serverText = Translation.getForServerMessage(welcomeMsg)
        text = Translation.get('manage_msg.welcome_message', message: serverText)
        @chatController.handleServerMessage(text)


    _handleChannelJoinFail: (errorMsg) =>
        serverText = Translation.getForServerMessage(errorMsg)
        text = Translation.get('manage_msg.channel_join_failed', reason: serverText)
        @chatController.handleServerMessage(text, true)

    _handleChannelLeaveFail: (channel, timestamp, errorMsg) =>
        serverText = Translation.getForServerMessage(errorMsg)
        @chatController.handleChannelError(channel, timestamp, serverText)

    _handleChannelDeleteFail: (channel, timestamp, errorMsg) =>
        serverText = Translation.getForServerMessage(errorMsg)
        @chatController.handleChannelError(channel, timestamp, serverText)

    _handleChannelJoined: (channel, timestamp, data) =>
        isOpeningJoin = @chatController.handleChannelJoined(channel, timestamp, data)
        @_sendChannelHistoryRequest(channel) if isOpeningJoin  # Only request history, if channel was not already opened

    _handleChannelLeft: (channel, timestamp, data) =>
        @chatController.handleChannelLeft(channel, timestamp, data)

    _handleChannelDeleted: (channel, timestamp, data) =>
        @chatController.handleChannelDeleted(channel, timestamp, data)


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
        isOwnHiddenChange = @_isOwnUser(data, 'user') and data.action in ['join', 'leave']
        isHistoric = @chatController.isHistoryReceivingChannel(channel)

        if not isOwnHiddenChange or isHistoric  # Ignore live notices on own channel join/leave
            @_simplifyUserIdentityData(data, 'user')
            @_addContentMetaInfo(data, 'user')
            @chatController.handleChannelUserChange(channel, timestamp, data)

    _handleChannelModeChange: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'actor')
        @chatController.handleChannelModeChange(channel, timestamp, data)

    _handleChannelMessage: (channel, timestamp, data) =>
        @_extractInlineAuthor(data, 'text', 'sender')
        @_simplifyUserIdentityData(data, 'sender')
        @_addContentMetaInfo(data, 'text')
        @chatController.handleChannelMessage(channel, timestamp, data)
        @lastMessageSentStamp = 0 if data.isOwn

    _handleChannelNotice: (channel, timestamp, data) =>
        @_simplifyUserIdentityData(data, 'sender')
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
        # Ignore, if last message had not been returned from server yet, but was sent since 10 seconds
        return if @lastMessageSentStamp + 10000 > (new Date()).getTime()
        # Send message to server
        @lastMessageSentStamp = (new Date()).getTime()
        @socket.emit 'message#' + channel, messageText

    sendChannelLeaveRequest: (channel, isClose) ->
        @socket.emit 'leave#' + channel, isClose

    sendChannelDeleteRequest: (channel) ->
        @socket.emit 'delete#' + channel

    sendChannelJoinRequest: (channelName, channelPassword, isPublic, isForIrc) ->
        channelData = 
            title: channelName or ''
            password: channelPassword or ''
            isPublic: isPublic or false
            isForIrc: isForIrc or false
        @socket.emit 'join', channelData


    #
    # Helper methods
    #

    _extractInlineAuthor: (data, textProperty, nameProperty) ->
        ownIdentityData = @identityData or {}
        identData = data[nameProperty] or {}

        if identData.isIrcClient and identData.idGame
            fullText = data[textProperty]
            matchData = fullText.match(/<([^>]+)>[: ]/)

            if matchData?.length
                inlineText = matchData[0]
                extractedName = matchData[1].trim()
                data[textProperty] = fullText.replace(inlineText, '').trim()
                data.inlineAuthor = extractedName

    _simplifyUserIdentityData: (data, nameProperty='sender', extractInlineAuthor=false) ->
        data.isOwn = @_isOwnUser(data, nameProperty)
        data.isIrcSender = data[nameProperty]?.isIrcClient or false
        data.gameTag = data[nameProperty]?.gameTag or ''
        data[nameProperty] = data[nameProperty]?.name or data[nameProperty]?.id  # Extract nick name from sender data

    _addContentMetaInfo: (data, addressTextProperty='text') ->
        unless data.isOwn
            addressText = data[addressTextProperty] or ''
            data.isMentioningOwn = @_isAddressedToOwnUser(addressText, false)
            data.isAddressingOwn = @_isAddressedToOwnUser(addressText, true)

    _isOwnUser: (data, nameProperty='sender') ->
        ownIdentityData = @identityData or {}
        identData = data[nameProperty] or {}

        if identData.isIrcClient
            isFromOwnGame = (String(identData.idGame) is String(ownIdentityData.idGame))
            isFromOwnName = (data.inlineAuthor is ownIdentityData.name)
            return (isFromOwnGame and isFromOwnName)

        return (String(identData.id) is String(ownIdentityData.id))

    _isAddressedToOwnUser: (addressText, onlyExplicitly) ->
        searchName = @identityData.name
        searchName = "((@#{searchName})|(#{searchName}:))" if onlyExplicitly  # Nick must be prefixed with "@" or postfixed with a colon
        searchRegex = new RegExp("(^|[^_a-z0-9])#{searchName}([^_a-z0-9]|$)", 'gim')

        return ((addressText.match(searchRegex)?.length or 0) isnt 0)



