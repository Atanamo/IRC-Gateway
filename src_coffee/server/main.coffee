
## Include libraries
fs = require 'fs'
https = require 'https'
express = require 'express'
socketio = require 'socket.io'
Q = require 'q'

## Include app modules
Config = require './config'
Logger = require './logger'
Database = require './database'

SocketHandler = require './sockethandler'
BotManager = require './botmanager'

## Configure global libraries
Q.longStackSupport = Config.DEBUG_ENABLED  # On debug mode, enable better stack trace support for promises (Performance overhead)

## Create library API objects
httpsOptions =
    cert: fs.readFileSync(Config.SSL_CERT_PATH)
    key: fs.readFileSync(Config.SSL_KEY_PATH)

app = express()
server = https.createServer(httpsOptions, app)  # Create HTTP server instance
io = socketio.listen(server)  # Listen for Websocket requests on server

## Create app objects
db = new Database()           # Create database wrapper object
log = Logger

## Set object to global scope
global.Q = Q
global.io = io
global.db = db
global.log = log


## Main class
class Gateway
    socketHandler: null
    botManager: null

    constructor: ->
        @_bindServerEvents()
        @botManager = new BotManager()
        @socketHandler = new SocketHandler(@botManager.addGameBotToChannel)

    _bindServerEvents: ->
        serverRootDir = process.cwd()

        ## Register http server events
        app.get '/', (request, response) ->
            response.sendFile "index.html", {root: serverRootDir}

        app.get '/js/:file', (request, response) ->
            filename = request.params.file
            log.info 'Requested script file:', filename

            response.sendFile filename, {root: "#{serverRootDir}/src_js/webclient/"}, (err) ->
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
            log.info "Start listening on port #{Config.WEB_SERVER_PORT}..."
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

        process.on 'unhandledRejection', (err) =>
            log.error err, 'unhandled promise rejection'

    _shutdown: ->
        @botManager.shutdown()
        db.disconnect()



# Run main class
main = new Gateway()
main.start()

