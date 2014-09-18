
# Include libraries
irc = require 'irc';

# Include app modules
Config = require './config'


# Bot class
class SchizoBot

    constructor: (@gameData) ->
        console.log 'Constructing new Bot...'

        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = 'GalaxyBot' + @gameData.id
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.name)

        # Create client instance (but dont connect)
        @client = new irc.Client Config.IRC_SERVER_IP, @nickName,
            #channels: [Config.IRC_CHANNEL_GLOBAL, Config.IRC_CHANNEL_INGAME_PATTERN]
            channels: [Config.IRC_CHANNEL_GLOBAL]
            port: Config.IRC_SERVER_PORT
            userName: @userName
            realName: @realName
            autoConnect: false              # Dont connect on client instantiation
            debug: true
            floodProtection: true           # Protect the bot from beeing kicket, if users are flooding
            floodProtectionDelay: 10        # Delay messages with 10ms to avoid flooding

        @client.addListener 'message', @handleMessage


    start: (channelList) ->
        # Start 
        console.log 'Connecting Bot...'

        @client.connect
            callback: ->
                console.log 'Connected succesfully!'


    handleMessage: (from, to, message, isSecondTry=false) =>
        unless isSecondTry                                          ## TODO: why is always isSecondTry = true ?
            console.log 'FIRST TRY'

            if message.indexOf(@nickName + ':') > -1                ## TODO: why is the command not recognized?
                console.log 'HANDLING'
                return @handleMessageToBot(from, to, message)

        console.log 'DONT HANDLING'
        #broudcast...

    handleMessageToBot: (from, to, message) =>
        if message.indexOf('galaxy?') > -1
            @client.say(to, 'Galaxy: ' + @realName)
        else
            #@handleMessage(from, to, message, true)


# Export class
module.exports = SchizoBot



