
# Include app modules
Config = require './config'
AbstractBot = require './bot'


## Abstraction of an IRC bot, which is responsible for all game worlds at once
## and which therefor exists as singleton.
##
class MonoBot extends AbstractBot
    @_instance: null

    gameData: null
    nickName: ''
    userName: ''
    realName: ''

    constructor: (arg=null) ->
        return if arg?

        # TODO
        @gameData =
            id: 'mono'
            title: 'Multiverse'

        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = Config.BOT_USERNAME_PATTERN.replace(/<id>/i, @gameData.id)
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.title)

        # Create client instance
        super()

    @getInstance: ->
        unless @_instance?
            @_instance = new MonoBot()
        return @_instance

    # @override
    stop: (gameID) ->
        log.info "Removing bot '#{@nickName}' from channels of game ##{gameID}..."
        return @_disconnectFromChannels(
            disconnectServer: false
            filterGameID: gameID
        )

    # @override
    getID: ->
        return @gameData.id

    # @override
    getNickName: ->
        return @nickName

    # @override
    getDetailName: ->
        return @gameData.title


# Export class
module.exports = MonoBot

