
## Include libraries
http = require 'http'
express = require 'express'
socketio = require 'socket.io'
Q = require 'q'

## Include app modules
Config = require './config'
Logger = require './logger'
Database = require './database'

SocketHandler = require './sockethandler'
BotManager = require './botmanager'

## Create library API objects
app = express()
server = http.createServer(app)    # Create HTTP server instance
io = socketio.listen(server)       # Listen for Websocket requests on server

## Create app objects
db = new Database()                # Create database wrapper object
log = Logger

## Set object to global scope
GLOBAL.Q = Q
GLOBAL.io = io
GLOBAL.db = db
GLOBAL.log = log


## Main class
class Gateway
    socketHandler: null
    botManager: null

    constructor: ->
        @_bindServerEvents()
        @botManager = new BotManager()
        @socketHandler = new SocketHandler(@botManager.addGameBotToChannel)

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


    start: ->
        ## Start the chat gateway ##
        @_setupProcess()

        # Register for socket events (But don't start listening)
        @socketHandler.start()

        # Connect database
        log.info 'Connecting database...'
        startupPromise = db.connect()

        # Create the bot channels, also create and connect the bots
        startupPromise = startupPromise.then =>
            return @botManager.start()

        # Start listening for socket.io emits and for HTTP requests
        startupPromise = startupPromise.then =>
            log.info 'Start listening...'
            server.listen(Config.WEB_SERVER_PORT)

        # End chain to observe errors
        startupPromise.done()

    _setupProcess: ->
        process.on 'exit', (code) =>
            log.info 'Exiting with code:', code
            @_shutdown()

        process.on 'uncaughtException', (err) =>
            log.error err, 'process'
            process.exit(err.code or 99)

    _shutdown: ->
        @botManager.shutdown()
        db.disconnect()



# Run main class
main = new Gateway()
main.start()

