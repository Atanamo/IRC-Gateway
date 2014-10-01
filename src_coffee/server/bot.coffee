
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
        #TODO: listen for command /me

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
        @_sendUserListRequestToIrcChannel(channel) if joinedNick isnt @nickName  # Don't request new user list, if bot joined itself
        @_sendUserChangeToWebChannel(channel, 'join', 'join', joinedNick)

    _handleIrcChannelPart: (channel, partedNick) =>
        @_sendUserListRequestToIrcChannel(channel)
        @_sendUserChangeToWebChannel(channel, 'part', 'part', partedNick)

    _handleIrcMessageToBot: (senderNick, message, fullData, channel=null) =>
        # Create responding function
        respondFunc = (messageText) => @_respondToIrcQuery(senderNick, messageText)
        if channel?
            respondFunc = (messageText) => @_respondToIrcChannel(channel, senderNick, messageText)

        # Sanitize message
        message = message.toLowerCase()

        # Check for a bot command
        return if @_checkRespondForGalaxyName(message, respondFunc)
        return if @_checkRespondForNumberOfClients(message, respondFunc)
        return if @_checkRespondForHelp(message, respondFunc)

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
        @_sendToWebChannel(channel, 'handleBotChannelUserList', nickList)

    _handleIrcTopicChange: (channel, topic, nick) =>
        @_sendToWebChannel(channel, 'handleBotTopicChange', topic, nick)


    #
    # Bot command routines
    #

    _checkRespondForGalaxyName: (message, respondFunc) ->
        if message.indexOf('galaxy?') > -1
            respondFunc('Galaxy = ' + @gameData.name)
            return true
        return false

    _checkRespondForNumberOfClients: (message, respondFunc) ->
        if message.indexOf('players?') > -1
            firstKey = Object.keys(@botChannelList)[0]
            clientsNum = 0
            if firstKey?
                botChannel = @botChannelList[firstKey]
                clientsNum = botChannel.getNumberOfClients()
            respondFunc('Players online = ' + clientsNum)
            return true
        return false


    _checkRespondForHelp: (message, respondFunc) ->
        if message.indexOf('help') > -1
            commandsText = ''
            commandsText += 'galaxy?  ---  What is the name of my galaxy?\n'
            commandsText += 'players?  ---  How many players of my galaxy are currently online?\n'
            commandsText += 'help  ---  Prints you this help\n'
            respondFunc('I understand following commands:\n' + commandsText)
            return true
        return false


    #
    # Sending routines
    #

    _sendToWebChannel: (channelName, botChannelHandlingFuncName, handlingFuncArgs...) ->
        targetBotChannel = @botChannelList[channelName]
        targetBotChannel?[botChannelHandlingFuncName]?(handlingFuncArgs...)

    _sendUserChangeToWebChannel: (channelName, args...) ->
        @_sendToWebChannel(channelName, 'handleBotChannelUserChange', args...)

    _sendMessageToWebChannel: (channelName, senderNick, messageText) ->
        @_sendToWebChannel(channelName, 'handleBotMessage', senderNick, messageText)

    _sendUserListRequestToIrcChannel: (channelName) ->
        @client.send('names', channelName)

    _respondToIrcQuery: (receiverNick, messageText) ->
        @client.say(receiverNick, messageText)

    _respondToIrcChannel: (channelName, receiverNick, messageText) ->
        fullMessageText = "@#{receiverNick}:  #{messageText}"
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



