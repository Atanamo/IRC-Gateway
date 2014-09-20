
# Include libraries
irc = require 'irc';

# Include app modules
Config = require './config'


# Bot class
class SchizoBot

    gameData: null
    botChannel: null

    constructor: (@botChannel, @gameData) ->
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

        @client.addListener 'message', @_handleIrcMessage


    start: (channelList) ->
        # Start 
        console.log 'Connecting Bot...'

        @client.connect
            callback: ->
                console.log 'Connected succesfully!'

    getID: ->
        return @gameData.id


    #
    # IRC event handlers
    #

    _handleIrcMessage: (from, to, message, isSecondTry=false) =>
        unless isSecondTry                                          ## TODO: why is always isSecondTry = true ?
            console.log 'FIRST TRY'

            if message.indexOf(@nickName + ':') > -1                ## TODO: why is the command not recognized?
                console.log 'HANDLING'
                return @_handleIrcMessageToBot(from, to, message)

        console.log 'DONT HANDLING', from, to
        #broudcast...




    _handleIrcMessageToBot: (from, to, message) =>
        if message.indexOf('galaxy?') > -1
            @client.say(to, 'Galaxy: ' + @realName)
        else
            #@handleIrcMessage(from, to, message, true)


    #
    # BotChannel handling
    #

    handleWebClientMessage: (senderData, rawMessage) ->
        clientNick = senderData.name or 'Anonymous'
        messageText = "<#{clientNick}>: #{rawMessage}"

        @client.say(Config.IRC_CHANNEL_GLOBAL, messageText)




# Export class
module.exports = SchizoBot



