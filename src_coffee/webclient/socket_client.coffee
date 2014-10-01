
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
        @socket.on 'message', @_handleMessageReceive
        @socket.on 'joined', @_handleChannelJoined
        @socket.on 'channel_clients', @_handleChannelClientList

        @socket.on 'channel_topic', @_handleChannelTopic


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @chatController.handleServerMessage('Connection established!')

    _handleServerWelcome: (text) =>
        @chatController.handleServerMessage(text)

    _handleMessageReceive: (channel, timestamp, data) =>
        data.timestamp = timestamp
        data.isOwn = (String(data.sender?.id) == String(@instanceData.id))
        data.sender = data.sender?.name or data.sender?.id  # Extract nick name from sender data
        @chatController.handleChannelMessage(channel, data)

    _handleChannelJoined: (channel, timestamp) =>
        @chatController.handleChannelJoined(channel)

    _handleChannelClientList: (channel, timestamp, clientList) =>
        @chatController.handleChannelClientList(channel, clientList)

    _handleChannelTopic: (channel, timestamp, data) =>
        data.author = data.author?.name
        @chatController.handleChannelTopic(channel, timestamp, data)


    #
    # GUI commands
    #

    sendMessage: (channel, messageText) ->
        @socket.emit 'message#' + channel, messageText



