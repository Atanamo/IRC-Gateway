
# Include app modules
Config = require './config'
AbstractBot = require './bot'


## Abstraction of an IRC bot, which is responsible for one single game world.
##
## For cases, where multiple bots are in the same channel, there is a master bot: 
## Only the master bot is allowed to forward common IRC events to the BotChannel 
## (Otherwise the same event would be triggered by each bot).
##
class GameBot extends AbstractBot

    gameData: null

    constructor: (@gameData) ->
        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = Config.BOT_USERNAME_PATTERN.replace(/<id>/i, @gameData.id)
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.title)

        # Create client instance
        super()

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
module.exports = GameBot

