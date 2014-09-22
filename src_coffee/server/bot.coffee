
# Include libraries
irc = require 'irc';

# Include app modules
Config = require './config'


# Bot class
class SchizoBot

    gameData: null
    botChannel: null
    ircChannelName: Config.IRC_CHANNEL_GLOBAL

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
            channels: [@ircChannelName]
            port: Config.IRC_SERVER_PORT
            userName: @userName
            realName: @realName
            autoConnect: false              # Dont connect on client instantiation
            debug: true
            floodProtection: true           # Protect the bot from beeing kicket, if users are flooding
            floodProtectionDelay: 10        # Delay messages with 10ms to avoid flooding

        # Create listeners
        @client.addListener "message#{@ircChannelName}", @_handleIrcMessageToChannel
        @client.addListener 'pm', @_handleIrcMessageToBot


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

    _handleIrcMessageToBot: (from, message, fullData, isChannelMessage=false) =>
        # Create responding function
        respondFunc = (messageText) => @_respondToIrcQuery(from, messageText)
        if isChannelMessage
            respondFunc = (messageText) => @_respondToIrcChannel(@ircChannelName, messageText)

        # Check for bot command
        if message.indexOf('galaxy?') > -1
            respondFunc('Galaxy: ' + @gameData.name)
            return

        # Fallback response
        if isChannelMessage
            respondFunc('Sry, what?')
        else
            # TODO: Print help
            respondFunc('Unknown command')


    _handleIrcMessageToChannel: (from, message, fullData) =>
        if 0 <= message.indexOf("#{@nickName}:") <= 3  # Recognize public talk to
            @_sendMessageToWebClients(from, message)    # Mirror command to web channel
            @_handleIrcMessageToBot(from, message, fullData, true)
        else
            @_sendMessageToWebClients(from, message)


    #
    # Sending routines
    #

    _sendMessageToWebClients: (senderNickName, messageText) =>
        @botChannel.handleBotMessage(senderNickName, messageText)

    _respondToIrcQuery: (receiverNickName, messageText) ->
        @client.say(receiverNickName, messageText)

    _respondToIrcChannel: (channelName, messageText) ->
        @client.say(channelName, messageText)
        @_sendMessageToWebClients(@nickName, messageText)  # Mirror response to web channel


    #
    # BotChannel handling
    #

    handleWebClientMessage: (senderIdentity, rawMessage) ->
        clientNick = senderIdentity.getName()
        messageText = "<#{clientNick}>: #{rawMessage}"

        @client.say(@ircChannelName, messageText)




# Export class
module.exports = SchizoBot



