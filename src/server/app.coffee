
## Include libraries
Q = require 'q'
fs = require 'fs'
path = require 'path'
https = require 'https'
express = require 'express'

## Include app modules
config = require './config'
log = require './logger'
db = require './database'
socketioWrapper = require './socketserver'

## Include app classes
SocketHandler = require './sockethandler'
BotManager = require './botmanager'

## Helper functions
resolvePath = (wildPath) ->
    resultPath = String(wildPath)
    # Resolve placeholder for package root directory
    resultPath = resultPath.replace('<package_dir>', path.join(__dirname, '..', '..'))
    # Resolve placeholder for process working directory
    resultPath = resultPath.replace('<working_dir>', process.cwd())
    # Finally normalize
    return path.normalize(resultPath)

## Configure global libraries
Q.longStackSupport = config.DEBUG_ENABLED  # On debug mode, enable better stack trace support for promises (Performance overhead)

## Create library API objects
httpsOptions =
    cert: fs.readFileSync(resolvePath(config.SSL_CERT_PATH))
    key: fs.readFileSync(resolvePath(config.SSL_KEY_PATH))

app = express()
server = https.createServer(httpsOptions, app)  # Create HTTP server instance
socketServer = socketioWrapper.bindToWebserver(server)  # Listen for Websocket requests on server


## Main class
class Gateway
    isStarted = false

    socketHandler: null
    botManager: null

    constructor: ->
        @_bindServerEvents()
        @botManager = new BotManager()
        @socketHandler = new SocketHandler(socketServer, @botManager.addGameBotToChannel)

    _bindServerEvents: ->
        # Listener for static files (index.html, style, etc.)
        if config.WEB_SERVER_STATICS_DELIVERY_DIR?
            staticFilesDir = resolvePath(config.WEB_SERVER_STATICS_DELIVERY_DIR)
            log.info "Webserver directory for index file: #{staticFilesDir}"

            app.get '/', (request, response) ->
                response.sendFile 'index.html', {root: staticFilesDir}, (err) ->
                    if err? then response.status(404).send 'File not found'

            app.get '/:file', (request, response) ->
                filename = request.params.file
                log.debug 'Requested static file:', filename

                response.sendFile filename, {root: staticFilesDir}, (err) ->
                    if err? then response.status(404).send 'File not found'

        # Listener for script files
        if config.WEB_SERVER_CLIENT_DELIVERY_DIR?
            clientFilesDir = resolvePath(config.WEB_SERVER_CLIENT_DELIVERY_DIR)
            log.info "Webserver directory for webclient files: #{clientFilesDir}"

            app.get '/chat/webclient.js', (request, response) ->
                response.sendFile "webclient.js", {root: "#{clientFilesDir}/"}, (err) ->
                    if err? then response.status(404).send 'File not found'

            app.get '/chat/webclient/:file', (request, response) ->
                filename = request.params.file
                log.debug 'Requested webclient file:', filename

                response.sendFile filename, {root: "#{clientFilesDir}/webclient/"}, (err) ->
                    if err? then response.status(404).send 'File not found'

        # Listener for server stop
        server.on 'close', ->
            log.info 'Server shut down'

    # Starts the chat gateway
    start: ->
        if isStarted
            log.error 'Gateway not stopped yet, cannot restart!', 'gateway main'
            return
        isStarted = true

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
            log.info "Start listening on port #{config.WEB_SERVER_PORT}..."
            server.listen(config.WEB_SERVER_PORT)

        # End chain to observe errors
        startupPromise.done()

    # Stops the chat gateway
    stop: (callback=null) ->
        return unless isStarted
        shutdownCallback = =>
            isStarted = false
            callback?()
        @_shutdown(shutdownCallback)

    _setupProcess: ->
        process.on 'exit', (code) =>
            log.info 'Exiting with code:', code
            @_shutdown()

        process.on 'uncaughtException', (err) =>
            log.error err, 'process'
            process.exit(err.code or 99)

        process.on 'unhandledRejection', (err) =>
            log.error err, 'unhandled promise rejection'

    _shutdown: (callback) ->
        promise = @botManager.shutdown()
        promise = promise.then =>
            # Wait some additional time to allow sending quit messages
            delayDeferred = Q.defer()
            setTimeout(=>
                delayDeferred.resolve()
            , 500)
            return delayDeferred.promise
        promise = promise.then =>
            server.close()  # Stop accepting new connections
            @socketHandler.stop()  # Stop socket.io
        promise = promise.then =>
            # Wait some additional time to allow finishing database queries
            delayDeferred = Q.defer()
            setTimeout(=>
                delayDeferred.resolve()
            , config.CLIENTS_DISCONNECT_DELAY + 1500)
            return delayDeferred.promise
        promise = promise.then =>
            return db.disconnect()
        promise = promise.then =>
            callback?()
        promise.done()



## Export class
module.exports = Gateway
