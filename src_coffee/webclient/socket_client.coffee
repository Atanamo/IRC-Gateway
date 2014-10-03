
# Controller class to handle communication with server
class this.SocketClient

    chatController: null
    socket: null

    serverIP: ''
    serverPort: 0
    instanceData: {}

    constructor: (@chatController, @serverIP, @serverPort, @instanceData) ->

    start: ->
        console.debug "Connecting to: #{@serverIP}:#{@serverPort}"

        @socket = io.connect("#{@serverIP}:#{@serverPort}")

        @socket.on 'connect', @_handleServerConnect      # Build-in event
        @socket.on 'welcome', @_handleServerWelcome
        @socket.on 'message', @_handleChannelMessage
        @socket.on 'notice', @_handleChannelNotice
        @socket.on 'joined', @_handleChannelJoined
        @socket.on 'channel_topic', @_handleChannelTopic
        @socket.on 'channel_clients', @_handleChannelUserList
        @socket.on 'user_change', @_handleChannelUserChange
        @socket.on 'mode_change', @_handleChannelModeChange


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @chatController.handleServerMessage('Connection established!')

    _handleServerWelcome: (text) =>
        @chatController.handleServerMessage(text)

    _handleChannelJoined: (channel, timestamp) =>
        @chatController.handleChannelJoined(channel, timestamp)

    _handleChannelTopic: (channel, timestamp, data) =>
        @simplifyUserIdentityData(data, 'author')
        @chatController.handleChannelTopic(channel, timestamp, data)

    _handleChannelUserList: (channel, timestamp, clientList) =>
        @chatController.handleChannelUserList(channel, clientList)

    _handleChannelUserChange: (channel, timestamp, data) =>
        console.log 'USER CHANGE', channel, timestamp, data

        @simplifyUserIdentityData(data, 'user')
        @chatController.handleChannelUserChange(channel, timestamp, data)

    _handleChannelModeChange: (channel, timestamp, data) =>
        console.log 'MODE CHANGE', channel, timestamp, data
        #modeText = if isEnabled then "+#{mode}" else "-#{mode}"

    _handleChannelMessage: (channel, timestamp, data) =>
        @simplifyUserIdentityData(data)
        @chatController.handleChannelMessage(channel, timestamp, data)

    _handleChannelNotice: (channel, timestamp, data) =>
        @simplifyUserIdentityData(data)
        @chatController.handleChannelNotice(channel, timestamp, data)


    #
    # GUI commands
    #

    sendMessage: (channel, messageText) ->
        @socket.emit 'message#' + channel, messageText


    #
    # Helper methods
    #

    simplifyUserIdentityData: (data, nameProperty='sender') ->
        data.isOwn = (String(data[nameProperty]?.id) == String(@instanceData.id))
        data[nameProperty] = data[nameProperty]?.name or data[nameProperty]?.id  # Extract nick name from sender data

