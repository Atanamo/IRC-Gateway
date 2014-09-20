
# https://www.openshift.com/blogs/building-social-irc-bots-with-nodejs-part-1
# https://github.com/martynsmith/node-irc

# PROBLEM: Standard IRC port blocked on OpenShift ???
# - http://www.youtube.com/watch?v=9GySwvpET1s
# - http://middlewaremagic.com/jboss/?p=2305

## Include libraries
express = require 'express'
http = require 'http'
socketio = require 'socket.io'

## Include app modules
Config = require './config'
Logger = require './logger'
Database = require './database'
Channel = require './channel'
BotChannel = require './botchannel'
Bot = require './bot'

## Create library API objects
app = express()
server = http.createServer(app)    # Create HTTP server instance
io = socketio.listen(server)       # Listen for Websocket requests on server

## Create app objects
db = new Database()                # Create database wrapper object
log = Logger

## Set object to global scope
GLOBAL.io = io
GLOBAL.db = db
GLOBAL.log = log


## Main class
class Gateway
    constructor: ->
        @_bindServerEvents()
        @_bindSocketGlobalEvents()

    _bindServerEvents: ->
        ## Register http server events
        app.get '/', (request, response) ->
            response.sendfile "./index.html"

        app.get '/js/:file', (request, response) ->
            filename = request.params.file
            log.info 'Requested script file: ' + filename

            response.sendfile "./src_js/webclient/#{filename}", null, (err) ->
                if err? then response.send 'File not found'

        server.on 'close', ->
            log.info 'Server shut down'

    _bindSocketGlobalEvents: ->
        ## Register common websocket events
        io.sockets.on 'connection', @_handleClientConnect

    _bindSocketClientEvents: (clientSocket) ->
        ## Register client socket events
        #clientSocket.on 'join', (data) => @handleClientJoin(clientSocket, data)
        clientSocket.on 'disconnect', @_handleClientDisconnect


    _handleClientConnect: (clientSocket) =>
        log.info 'Client connected...'

        # Set client identification data
        # TODO
        clientSocket.identData =
            id: 42
            name: 'TempName'
            title: 'Temp Title'
            game_id: 123

        # Let client join default channel
        botChannel = BotChannel.getInstance()
        botChannel.addClient(clientSocket, true)

        # Let client join to saved channels
        channelList = db.getClientChannels(clientSocket)

        for channelData in channelList
            channel = Channel.getInstance(channelData.name)
            channel.addClient(clientSocket, true)

        # Bind socket events to new client
        @_bindSocketClientEvents(clientSocket)

        # Emit initial events for new client
        clientSocket.emit 'welcome', 'hello out there!'


    _handleClientDisconnect: (clientSocket) =>
        log.info 'Client disconnected...'


    start: ->
        ## Start the chat gateway ##

        # Start listening for HTTP requests
        log.info 'Connecting database...'
        db.connect()

        # Start listening for HTTP requests
        log.info 'Start listening...'
        server.listen(8080)

        # Create and connect the bots
        @_setupBots()


    _setupBots: ->
        botChannel = BotChannel.getInstance()

        # TODO: Multiple bots, each for one galaxy. Singleton-Concept?
        bot = new Bot botChannel,
            id: 123
            name: 'Eine Testgalaxie'

        bot.start()

        # Add bots to botChannel
        botChannel.addBot(bot)




# Run main class
main = new Gateway()
main.start()

