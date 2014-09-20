
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


    #
    # Socket message handling
    #

    _handleServerConnect: =>
        @chatController.handleServerMessage('Connection established!')

    _handleServerWelcome: (text) =>
        @chatController.handleServerMessage(text)

    _handleMessageReceive: (data) =>
        data.isOwn = (String(data.sender?.id) == String(@instanceData.id))
        data.sender = data.sender?.name or data.sender?.id  # Extract nick name from sender data
        @chatController.handleChannelMessage(data)

    _handleChannelJoined: (channel) =>
        @chatController.handleChannelJoined(channel)


    #
    # GUI commands
    #

    sendMessage: (channel, messageText) ->
        @socket.emit 'message#' + channel, messageText



