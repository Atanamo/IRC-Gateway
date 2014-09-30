
# Include libraries
irc = require 'irc';

# Include app modules
Config = require './config'


## Abstraction of an IRC bot.
## The bot is able to join multiple IRC channels, each must be associated with a BotChannel.
## Therefor, the bot is mapping each BotChannel to its IRC channel.
##
class SchizoBot

    gameData: null
    botChannel: null

    botChannelList: null
    connectionPromise: null

    constructor: (@gameData) ->
        @botChannelList = {}

        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = 'GalaxyBot' + @gameData.id
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.name)

        log.info "Creating bot '#{@nickName}'..."

        # Create client instance (but dont connect)
        @client = new irc.Client Config.IRC_SERVER_IP, @nickName,
            port: Config.IRC_SERVER_PORT
            userName: @userName
            realName: @realName
            autoRejoin: true
            autoConnect: false              # Dont connect on client instantiation
            debug: true
            floodProtection: true           # Protect the bot from beeing kicket, if users are flooding
            floodProtectionDelay: 10        # Delay messages with 10ms to avoid flooding
            stripColors: true               # Strip mirc colors

        # Create listeners
        @client.addListener "error", @_handleIrcError
        @client.addListener 'raw', @_handleIrcRawCommand
        @client.addListener 'registered', @_handleIrcConnectConfirmation

        @client.addListener 'pm', @_handleIrcMessageToBot
        @client.addListener "message#", @_handleIrcMessageToChannel

        @client.addListener 'names', @_handleIrcUserList
        @client.addListener 'topic', @_handleIrcTopicChange

        @client.addListener 'join', @_handleIrcChannelJoin
        @client.addListener 'part', @_handleIrcChannelPart


    start: (channelList) ->
        # Start 
        log.info "Connecting bot '#{@nickName}'..."
        deferred = Q.defer()

        @client.connect (data) =>
            log.info "Bot '#{@nickName}' connected succesfully!"
            deferred.resolve()

        @connectionPromise = deferred.promise

        return @connectionPromise

    getID: ->
        return @gameData.id


    #
    # IRC event handlers
    #

    _handleIrcError: (commandData) =>
        log.error commandData, "IRC server (Bot '#{@nickName}')"

    _handleIrcRawCommand: (data) =>
        #switch data.command
        #    when 'rpl_luserunknown', 'rpl_umodeis'
        #        log.info 'Unhandled command', data


    _handleIrcConnectConfirmation: (commandData) =>
        if commandData.command = 'rpl_welcome'
            welcomeMessage = commandData.args?[1]
            if welcomeMessage?
                log.info "Welcome message for bot '#{@nickName}':", welcomeMessage

    _handleIrcChannelJoin: (channel, joinedNick) =>
        infoMessage = "#{joinedNick} has joined #{channel} on IRC"
        @_sendUserListUpdateToWebChannel(channel, infoMessage)

    _handleIrcChannelPart: (channel, leftNick) =>
        infoMessage = "#{leftNick} has left #{channel} on IRC"
        @_sendUserListUpdateToWebChannel(channel, infoMessage)

    _handleIrcMessageToBot: (senderNick, message, fullData, channel=null) =>
        # Create responding function
        respondFunc = (messageText) => @_respondToIrcQuery(senderNick, messageText)

        if channel?
            respondFunc = (messageText) => @_respondToIrcChannel(channel, senderNick, messageText)

        # Check for bot command
        if message.indexOf('galaxy?') > -1
            respondFunc('Galaxy = ' + @gameData.name)
            return

        # Fallback response
        if channel?
            respondFunc('Sry, what?')
        else
            # TODO: Print help
            respondFunc('Unknown command')


    _handleIrcMessageToChannel: (senderNick, channel, message, commandData) =>
        if 0 <= message.indexOf("#{@nickName}:") <= 3  # Recognize public talk to
            @_sendMessageToWebChannel(channel, senderNick, message)    # Mirror command to web channel
            @_handleIrcMessageToBot(senderNick, message, commandData, channel)
        else
            @_sendMessageToWebChannel(channel, senderNick, message)

    _handleIrcUserList: (channel, nickList) =>
        console.log 'NICKS', channel, nickList

    _handleIrcTopicChange: (channel, topic, nick) =>
        console.log 'TOPIC', channel, nick, topic
        @_sendToWebChannel(channel, 'handleBotTopicChange', topic, nick)


    #
    # Sending routines
    #

    _sendToWebChannel: (channelName, botChannelHandlingFuncName, handlingFuncArgs...) ->
        targetBotChannel = @botChannelList[channelName]
        targetBotChannel[botChannelHandlingFuncName]?(handlingFuncArgs...)

    _sendUserListUpdateToWebChannel: (channelName, infoMessageText) ->
        # TODO: Send new user list and send info message
        targetBotChannel = @botChannelList[channelName]

    _sendMessageToWebChannel: (channelName, senderNick, messageText) ->
        @_sendToWebChannel(channelName, 'handleBotMessage', senderNick, messageText)

    _respondToIrcQuery: (receiverNick, messageText) ->
        @client.say(receiverNick, messageText)

    _respondToIrcChannel: (channelName, receiverNick, messageText) ->
        fullMessageText = "@#{receiverNick}: #{messageText}"
        @client.say(channelName, fullMessageText)
        @_sendMessageToWebChannel(channelName, @nickName, fullMessageText)  # Mirror response to web channel


    #
    # BotChannel handling
    #

    handleWebChannelJoin: (botChannel) ->
        ircChannelName = botChannel.getIrcChannelName()
        @botChannelList[ircChannelName] = botChannel
        log.info "Joining bot '#{@nickName}' to channel #{ircChannelName}..."
        @client.join(ircChannelName)

    handleWebClientMessage: (channelName, senderIdentity, rawMessage) ->
        clientNick = senderIdentity.getName()
        messageText = "<#{clientNick}>: #{rawMessage}"

        @client.say(channelName, messageText)




# Export class
module.exports = SchizoBot



