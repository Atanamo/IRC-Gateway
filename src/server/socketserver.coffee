
## Include libraries
socketio = require 'socket.io'

## Include app modules
log = require './logger'


## Helper for socket server
socketServer = null


## Simple wrapper for socket.io to bind and get the websockets API.
module.exports = {

    bindToWebserver: (server) ->
        socketServer = socketio.listen(server)
        return socketServer

    getBoundServer: ->
        return socketServer

    getSockets: ->
        unless socketServer?
            log.warn('No bound socket server to get sockets from!', 'SocketServer')
            return null
        return socketServer.sockets
}



