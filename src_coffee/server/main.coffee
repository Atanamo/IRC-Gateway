
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
GLOBAL.Q = Q
GLOBAL.io = io
GLOBAL.db = db
GLOBAL.log = log


## Main class
class Gateway
    socketHandler: null

    constructor: ->
        @_bindServerEvents()
        @socketHandler = new SocketHandler()

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

        # Connect database
        log.info 'Connecting database...'
        db.connect()

        # Start listening for HTTP requests
        log.info 'Start listening...'
        server.listen(8080)

        # Start listening for socket.io emits
        @socketHandler.start()

        # Create and connect the bots
        @_setupBots()


    _setupBots: ->
        botChannel = BotChannel.getInstance(Config.INTERN_BOT_CHANNEL_NAME, Config.IRC_CHANNEL_GLOBAL)  # TODO

        # TODO: Multiple bots, each for one galaxy. Singleton-Concept?
        bot = new Bot
            id: 123
            name: 'Eine Testgalaxie'

        startPromise = bot.start()

        # Add bots to botChannel
        startPromise.then =>
            botChannel.addBot(bot)



            bot2 = new Bot
                id: 124
                name: 'Eine Testgalaxie 2'

            startPromise2 = bot2.start()

            startPromise2.then =>
                botChannel.addBot(bot2)




# Run main class
main = new Gateway()
main.start()

