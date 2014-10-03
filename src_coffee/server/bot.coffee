
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

        @client.addListener 'join', @_handleIrcChannelJoin
        @client.addListener 'part', @_handleIrcChannelPart
        @client.addListener 'kick', @_handleIrcChannelKick
        @client.addListener 'quit', @_handleIrcChannelQuit
        @client.addListener 'kill', @_handleIrcUserKill

        @client.addListener 'nick', @_handleIrcUserNickChange
        @client.addListener '+mode', @_handleIrcModeAdd
        @client.addListener '-mode', @_handleIrcModeRemove

        @client.addListener 'names', @_handleIrcUserList
        @client.addListener 'topic', @_handleIrcTopicChange

        @client.addListener 'pm', @_handleIrcMessageToBot
        @client.addListener "message#", @_handleIrcMessageToChannel
        @client.addListener "notice", @_handleIrcNotice

        @client.addListener "ctcp-privmsg", @_handleIrcCommandViaCTCP
        @client.addListener "ctcp-notice", @_handleIrcCommandReplyViaCTCP
        @client.addListener "ctcp-version", @_handleIrcVersionRequestViaCTCP


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

    _handleIrcError: (rawData) =>
        log.error rawData, "IRC server (Bot '#{@nickName}')"

    _handleIrcRawCommand: (data) =>
        #switch data.command
        #    when 'rpl_luserunknown', 'rpl_umodeis'
        #        log.info 'Unhandled command', data

    _handleIrcConnectConfirmation: (rawData) =>
        if rawData.command = 'rpl_welcome'
            welcomeMessage = rawData.args?[1]
            if welcomeMessage?
                log.info "Welcome message for bot '#{@nickName}':", welcomeMessage


    _handleIrcChannelJoin: (channel, nick) =>
        @_sendUserListRequestToIrcChannel(channel) if nick isnt @nickName  # Don't request new user list, if bot joined itself
        @_sendToWebChannel(channel, 'handleBotChannelUserJoin', nick)

    _handleIrcChannelPart: (channel, nick, reason) =>
        @_sendUserListRequestToIrcChannel(channel)
        @_sendToWebChannel(channel, 'handleBotChannelUserPart', nick, reason)

    _handleIrcChannelKick: (channel, nick, actorNick, reason) =>
        # TODO: Specially handle own kick
        @_sendUserListRequestToIrcChannel(channel)
        @_sendToWebChannel(channel, 'handleBotChannelUserKick', nick, actorNick, reason)

    _handleIrcChannelQuit: (nick, reason, channels) =>
        # TODO: Specially handle own quit
        reason = reason.replace(/(^Quit$)|(^Quit: )/, '').trim() or null
        for channel in channels
            @_sendUserListRequestToIrcChannel(channel)
            @_sendToWebChannel(channel, 'handleBotChannelUserQuit', nick, reason)

    _handleIrcUserKill: (nick, reason, channels) =>
        # TODO: Specially handle own kill
        for channel in channels
            @_sendUserListRequestToIrcChannel(channel)
            @_sendToWebChannel(channel, 'handleBotChannelUserKill', nick, reason)

    _handleIrcUserNickChange: (oldNick, newNick, channels) =>
        for channel in channels
            @_sendUserListRequestToIrcChannel(channel)
            @_sendToWebChannel(channel, 'handleBotChannelUserRename', oldNick, newNick)


    _handleIrcModeAdd: (channel, actorNick, mode, argument) =>
        @_handleIrcModeChange(channel, actorNick, mode, true, argument)

    _handleIrcModeRemove: (channel, actorNick, mode, argument) =>
        @_handleIrcModeChange(channel, actorNick, mode, false, argument)

    _handleIrcModeChange: (channel, actorNick, mode, isEnabled, argument) =>
        @_sendUserListRequestToIrcChannel(channel) unless mode is 'b'  # Only if mode is not ban
        @_sendToWebChannel(channel, 'handleBotChannelModeUpdate', actorNick, mode, isEnabled, argument)


    _handleIrcUserList: (channel, nickList) =>
        @_sendToWebChannel(channel, 'handleBotChannelUserList', nickList)

    _handleIrcTopicChange: (channel, topic, nick) =>
        @_sendToWebChannel(channel, 'handleBotTopicChange', topic, nick)


    _handleIrcMessageToBot: (senderNick, message, rawData, channel=null) =>
        # Create responding function
        queryRespondFunc = (messageText) => @_respondToIrcQuery(senderNick, messageText)
        respondFunc = queryRespondFunc
        if channel?
            respondFunc = (messageText) => @_respondToIrcChannel(channel, senderNick, messageText)

        # Sanitize message
        message = message.toLowerCase()

        # Check for a bot command
        return if @_checkRespondForHelp(message, queryRespondFunc)  # Always respond to query
        return if @_checkRespondForGalaxyName(message, respondFunc)
        return if @_checkRespondForNumberOfClients(message, respondFunc)
        return if @_checkRespondForVersion(message, respondFunc)

        # Fallback response
        defaultResponse = 'Send me "help" for a list of available commands'
        if channel?
            respondFunc('Sry, what?')
        else
            respondFunc("Unknown command '#{message}'. --- #{defaultResponse}")

    _handleIrcMessageToChannel: (senderNick, channel, message, rawData) =>
        if 0 <= message.indexOf("#{@nickName}:") <= 3  # Recognize public talk to
            @_sendMessageToWebChannel(channel, senderNick, message)    # Mirror command to web channel
            @_handleIrcMessageToBot(senderNick, message, rawData, channel)
        else
            @_sendMessageToWebChannel(channel, senderNick, message)


    _handleIrcNotice: (senderNick, targetNickOrChannel, notice) =>
        return if not senderNick? and targetNickOrChannel.toLowerCase() is 'auth'  # Ignore auth notices from server
        if targetNickOrChannel is @nick
            log.debug "Notice by #{senderNick} to #{targetNickOrChannel}: #{notice}"
        else
            @_sendToWebChannel(targetNickOrChannel, 'handleBotNotice', senderNick, notice)


    _handleIrcCommandViaCTCP: (senderNick, targetNickOrChannel, rawMessage) =>
        # This handler is triggered, whenever the bot receives a CTCP request or a CTCP command to a channel
        return unless targetNickOrChannel isnt @nick  # Ignore direct ctcp messages to bot
        return unless targetNickOrChannel?            # Ignore broken ctcp messages
        channel = targetNickOrChannel
        checkMessage = rawMessage.toLowerCase().trim()

        # Handle action command (/me) 
        if checkMessage.indexOf('action') is 0
            actionText = rawMessage.replace(/^(action)/i, '').trim()  # Extract action text
            noticeText = "#{senderNick} #{actionText}"  # Build complete notice
            @_sendToWebChannel(channel, 'handleBotNotice', senderNick, noticeText)

    _handleIrcCommandReplyViaCTCP: (senderNick, targetNickOrChannel, rawReplyMessage) =>
        # This handler should only be triggered, if the bot had sent a CTCP request to another IRC client before
        log.debug "Received CTCP reply from #{senderNick} to #{targetNickOrChannel}: #{rawReplyMessage}"

    _handleIrcVersionRequestViaCTCP: (senderNick, targetNickOrChannel) =>
        # This handler is specialized to a CTCP version request, but may could also be handled by @_handleIrcCommandViaCTCP()
        @_respondToIrcViaCTCP(senderNick, 'version', Config.BOT_VERSION_STRING)


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

    _checkRespondForVersion: (message, respondFunc) ->
        if message.indexOf('version') > -1
            respondFunc('Version = ' + Config.BOT_VERSION_STRING)
            return true
        return false

    _checkRespondForHelp: (message, respondFunc) ->
        if message.indexOf('help') > -1
            commandsText = ''
            commandsText += 'help  ---  Prints you this help (in the query)\n'
            commandsText += 'galaxy?  ---  What is the name of my galaxy?\n'
            commandsText += 'players?  ---  How many players of my galaxy are currently online?\n'
            commandsText += 'version  ---  Prints you my version info\n'
            respondFunc('I understand following commands:\n' + commandsText)
            return true
        return false


    #
    # Sending routines
    #

    _sendToWebChannel: (channelName, botChannelHandlingFuncName, handlingFuncArgs...) ->
        targetBotChannel = @botChannelList[channelName]
        targetBotChannel?[botChannelHandlingFuncName]?(handlingFuncArgs...)

    _sendMessageToWebChannel: (channelName, senderNick, messageText) ->
        @_sendToWebChannel(channelName, 'handleBotMessage', senderNick, messageText)

    _sendNoticeToWebChannel: (channelName, senderNick, noticeText) ->
        @_sendToWebChannel(channelName, 'handleBotNotice', senderNick, noticeText)

    _sendUserListRequestToIrcChannel: (channelName) ->
        @client.send('names', channelName)

    _respondToIrcViaCTCP: (receiverNick, ctcpCommand, responseText) ->
        ctcpText = "#{ctcpCommand} #{responseText}"
        @client.ctcp(receiverNick, 'notice', ctcpText)  # Send notice for a reply to command

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



