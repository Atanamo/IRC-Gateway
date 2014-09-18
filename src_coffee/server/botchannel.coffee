
## Include app modules
Config = require './config'
Channel = require './channel'


## Class definition
class BotChannel extends Channel
    @_instance: null

    #constructor: ->


    @getInstance: ->
        unless @_instance?
            @_instance = new BotChannel(Config.INTERN_BOT_CHANNEL_NAME)
            @_instances[@_instance.name] = @_instance
        return @_instance


    addClient: (clientSocket, isRejoin=false) ->
        super(clientSocket, true)   # true, because: dont do that: db.addClientToChannel(clientSocket, @name)



## Export class
module.exports = BotChannel

