
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
        @bindServerEvents()
        @bindSocketGlobalEvents()

    bindServerEvents: ->
        ## Register http server events
        app.get '/', (request, response) ->
            response.sendfile "./index.html"

        app.get '/js/:file', (request, response) ->
            filename = request.params.file
            log.info 'Requested script file: ' + filename

            response.sendfile "./src_js/#{filename}", null, (err) ->
                if err? then response.send 'File not found'

        server.on 'close', ->
            log.info 'Server shut down'

    bindSocketGlobalEvents: ->
        ## Register common websocket events
        io.sockets.on 'connection', @handleClientConnect

    bindSocketClientEvents: (clientSocket) ->
        ## Register client socket events
        #clientSocket.on 'join', (data) => @handleClientJoin(clientSocket, data)
        clientSocket.on 'disconnect', @handleClientDisconnect


    handleClientDisconnect: (clientSocket) =>
        log.info 'Client disconnected...'


    handleClientConnect: (clientSocket) =>
        log.info 'Client connected...'

        # Set client identification data
        clientSocket.identData =
            id: 42
            name: 'TempName'
            title: 'Temp Title'

        # Let client join default channel
        botChannel = BotChannel.getInstance()
        botChannel.addClient(clientSocket, true)

        # Let client join to saved channels
        channelList = db.getClientChannels(clientSocket)

        for channelData in channelList
            channel = Channel.getInstance(channelData.name)
            channel.addClient(clientSocket, true)

        # Bind socket events to new client
        @bindSocketClientEvents(clientSocket)

        # Emit initial events for new client
        clientSocket.emit 'welcome', 'hello out there!'


    start: ->
        ## Start the chat gateway ##

        # Start listening for HTTP requests
        log.info 'Connecting database...'
        db.connect()

        # Start listening for HTTP requests
        log.info 'Start listening...'
        server.listen(8080)

        ###
        bot = new Bot
            id: 123
            name: 'Eine Testgalaxie'

        bot.start()
        ###



# Run main class
main = new Gateway()
main.start()

