
# Include libraries
irc = require 'irc';

# Include app modules
Config = require './config'


## Abstraction of an IRC bot.
## The bot is able to join multiple IRC channels, each must be associated with a BotChannel.
## Therefor, the bot is mapping each BotChannel to its IRC channel.
##
## When an event on an IRC channel occurs, the bot forwards it to the associated BotChannel (If useful).
## The bot may also responds to a list of specified commands on an IRC channel or query.
##
## For cases, where multiple bots are in the same channel, there is a master bot: 
## Only the master bot is allowed to forward common IRC events to the BotChannel 
## (Otherwise the same event would be triggered by each bot).
##
class SchizoBot

    gameData: null
    nickName: ''
    userName: ''
    realName: ''

    client: null
    botChannelList: null
    masterChannelList: null
    connectionDeferred: null
    connectDateTime: null

    constructor: (@gameData) ->
        @botChannelList = {}
        @masterChannelList = {}
        @connectionDeferred = Q.defer()

        @nickName = Config.BOT_NICK_PATTERN.replace(/<id>/i, @gameData.id)
        @userName = Config.BOT_USERNAME_PATTERN.replace(/<id>/i, @gameData.id)
        @realName = Config.BOT_REALNAME_PATTERN
        @realName = @realName.replace(/<id>/i, @gameData.id)
        @realName = @realName.replace(/<name>/i, @gameData.title)

        log.info "Creating bot '#{@nickName}'..."

        # Create client instance (but dont connect)
        @client = new irc.Client Config.IRC_SERVER_IP, @nickName,
            port: Config.IRC_SERVER_PORT
            userName: @userName
            realName: @realName
            autoRejoin: true
            autoConnect: false                      # Dont connect on client instantiation
            debug: Config.DEBUG_IRC_COMM
            showErrors: true
            floodProtection: true                   # Protect the bot from beeing kicked, if users are flooding
            floodProtectionDelay: 100               # Delay time for messages to avoid flooding
            retryDelay: Config.BOT_RECONNECT_DELAY  # Delay time for reconnects
            stripColors: true                       # Strip mirc colors

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
        log.info "Connecting bot '#{@nickName}'..."
        @client.connect (data) =>
            log.info "Bot '#{@nickName}' connected succesfully!"
            #@connectionDeferred.resolve()
        return @connectionDeferred.promise

    stop: ->
        stopDeferred = Q.defer()
        log.info "Stopping bot '#{@nickName}'..."
        quitMessage = Config.BOT_QUIT_MESSAGE

        # Inform bot's web channels (in case, they weren't informed before)
        for key, channel of @botChannelList
            channel.handleBotQuit(this, quitMessage)

        # Disconnect from server
        @client.disconnect quitMessage, =>
            log.info "Bot '#{@nickName}' has disconnected!"
            # Create new connection deferred
            @connectionDeferred = Q.defer()
            # Resolve stop deferred
            stopDeferred.resolve()

        return stopDeferred.promise

    getConnectionPromise: ->
        return @connectionDeferred.promise

    getID: ->
        return @gameData.id

    getNickName: ->
        return @nickName

    getGameTitle: ->
        return @gameData.title

    getWebChannelList: ->
        return @botChannelList


    #
    # IRC event handlers
    #

    _handleIrcError: (rawData) =>
        log.error rawData, "IRC server (Bot '#{@nickName}')"

    _handleIrcRawCommand: (data) =>
        switch data.command
            when 'ERROR'
                @_handleIrcError(data)
            #when 'rpl_luserunknown', 'rpl_umodeis'
            #    log.info 'Unhandled command', data

    _handleIrcConnectConfirmation: (rawData) =>
        if rawData.command = 'rpl_welcome'
            confirmedNick = rawData.args?[0]
            welcomeMessage = rawData.args?[1]
            if welcomeMessage?
                log.debug "Welcome message for bot '#{@nickName}':", welcomeMessage
            if confirmedNick?
                @nickName = confirmedNick
        @connectDateTime = new Date()
        @connectionDeferred.resolve()

    _handleIrcChannelJoin: (channel, nick) =>
        return unless @_isChannelMaster(channel)
        @_sendUserListRequestToIrcChannel(channel) if nick isnt @nickName  # Don't request new user list, if bot joined itself
        @_sendToWebChannel(channel, 'handleBotChannelUserJoin', nick)

    _handleIrcChannelPart: (channel, nick, reason) =>
        return unless @_isChannelMaster(channel)
        @_sendUserListRequestToIrcChannel(channel) if nick isnt @nickName  # Don't request new user list, if bot parted itself
        @_sendToWebChannel(channel, 'handleBotChannelUserPart', nick, reason)

    _handleIrcChannelKick: (channel, nick, actorNick, reason) =>
        return unless @_isChannelMaster(channel)
        # TODO: Specially handle own kick
        @_sendUserListRequestToIrcChannel(channel)
        @_sendToWebChannel(channel, 'handleBotChannelUserKick', nick, actorNick, reason)

    _handleIrcChannelQuit: (nick, reason, channels) =>
        reason = reason.replace(/(^Quit$)|(^Quit: )/, '').trim() or null  # Remove default reason or reason prefix by server
        for channel in channels
            if @_isChannelMaster(channel)
                @_sendUserListRequestToIrcChannel(channel) if nick isnt @nickName
                @_sendToWebChannel(channel, 'handleBotChannelUserQuit', nick, reason)

    _handleIrcUserKill: (nick, reason, channels, rawData) =>
        if nick is @nickName
            # TODO: Specially handle own kill
            log.warn "Bot has been killed from server, reason: #{reason}", "Bot '#{@nickName}'"

        for channel in channels
            if @_isChannelMaster(channel)
                @_sendUserListRequestToIrcChannel(channel)
                @_sendToWebChannel(channel, 'handleBotChannelUserKill', nick, reason)

    _handleIrcUserNickChange: (oldNick, newNick, channels) =>
        for channel in channels
            if @_isChannelMaster(channel)
                @_sendUserListRequestToIrcChannel(channel)
                @_sendToWebChannel(channel, 'handleBotChannelUserRename', oldNick, newNick)


    _handleIrcModeAdd: (channel, actorNick, mode, argument) =>
        return unless @_isChannelMaster(channel)
        @_handleIrcModeChange(channel, actorNick, mode, true, argument)

    _handleIrcModeRemove: (channel, actorNick, mode, argument) =>
        return unless @_isChannelMaster(channel)
        @_handleIrcModeChange(channel, actorNick, mode, false, argument)

    _handleIrcModeChange: (channel, actorNick, mode, isEnabled, argument) =>
        @_sendUserListRequestToIrcChannel(channel) unless mode is 'b'  # Only if mode is not ban
        @_sendToWebChannel(channel, 'handleBotChannelModeUpdate', actorNick, mode, isEnabled, argument)


    _handleIrcUserList: (channel, nickList) =>
        return unless @_isChannelMaster(channel)
        @_sendToWebChannel(channel, 'handleBotChannelUserList', nickList)

    _handleIrcTopicChange: (channel, topic, nick) =>
        return unless @_isChannelMaster(channel)
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
        return if @_checkRespondForGalaxyStatus(message, respondFunc)
        return if @_checkRespondForGalaxyRound(message, respondFunc)
        return if @_checkRespondForNumberOfGalaxyClients(message, respondFunc)
        return if @_checkRespondForNumberOfClients(message, respondFunc, channel)
        return if @_checkRespondForConnectTime(message, respondFunc)
        return if @_checkRespondForVersion(message, respondFunc)

        # Fallback response
        defaultResponse = 'Send me "help" for a list of available commands'
        if channel?
            respondFunc('Sry, what?')
        else
            message = message.substr(0, 20) + '...' if message.length > 25
            respondFunc("Unknown command '#{message}'. --- #{defaultResponse}")

    _handleIrcMessageToChannel: (senderNick, channel, message, rawData) =>
        if @_isChannelMaster(channel)
            @_sendMessageToWebChannel(channel, senderNick, message)
        # Check for message to bot
        if 0 <= message.indexOf("#{@nickName}:") <= 3  # Recognize public talk to
            @_handleIrcMessageToBot(senderNick, message, rawData, channel)

    _handleIrcNotice: (senderNick, targetNickOrChannel, notice) =>
        return if not senderNick? and targetNickOrChannel.toLowerCase() is 'auth'  # Ignore auth notices from server
        if targetNickOrChannel is @nick
            log.debug "Notice by #{senderNick} to #{targetNickOrChannel}: #{notice}"
        else if @_isChannelMaster(targetNickOrChannel)
            @_sendNoticeToWebChannel(targetNickOrChannel, senderNick, notice)


    _handleIrcCommandViaCTCP: (senderNick, targetNickOrChannel, rawMessage) =>
        # This handler is triggered, whenever the bot receives a CTCP request or a CTCP command to a channel
        channel = targetNickOrChannel
        return unless @_isChannelMaster(channel)
        return unless targetNickOrChannel isnt @nick  # Ignore direct ctcp messages to bot
        return unless targetNickOrChannel?            # Ignore broken ctcp messages
        checkMessage = rawMessage.toLowerCase().trim()

        # Handle action command (/me) 
        if checkMessage.indexOf('action') is 0
            actionText = rawMessage.replace(/^(action)/i, '').trim()  # Extract action text
            noticeText = "#{senderNick} #{actionText}"  # Build complete notice
            @_sendNoticeToWebChannel(channel, senderNick, noticeText)

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
            respondFunc('Galaxy = ' + @gameData.title)
            return true
        return false

    _checkRespondForGalaxyStatus: (message, respondFunc) ->
        if message.indexOf('status?') > -1
            promise = db.getGameStatus(@gameData.id)
            promise.then (statusText) =>
                respondFunc("Status (#{@gameData.title}) = #{statusText}")
            return true
        return false

    _checkRespondForGalaxyRound: (message, respondFunc) ->
        if message.indexOf('round?') > -1 or message.indexOf('ticks?') > -1
            promise = db.getGameRound(@gameData.id)
            promise.then (roundNum) =>
                respondFunc("Round (#{@gameData.title}) = #{roundNum}")
            return true
        return false

    _checkRespondForNumberOfGalaxyClients: (message, respondFunc) ->
        if message.indexOf('players?') > -1
            channelName = channelName or Object.keys(@botChannelList)[0]
            clientsNum = 0
            if channelName?
                botChannel = @botChannelList[channelName]
                clientsNum = botChannel.getNumberOfBotDependentClients(@gameData.id)
            respondFunc("Galaxy players in #{channelName} = #{clientsNum}")
            return true
        return false

    _checkRespondForNumberOfClients: (message, respondFunc, channelName) ->
        if message.indexOf('users?') > -1
            channelName = channelName or Object.keys(@botChannelList)[0]
            clientsNum = 0
            if channelName?
                botChannel = @botChannelList[channelName]
                clientsNum = botChannel.getNumberOfClients()
            respondFunc("Total players in #{channelName} = #{clientsNum}")
            return true
        return false

    _checkRespondForConnectTime: (message, respondFunc) ->
        if message.indexOf('uptime') > -1
            currDateTime = new Date()
            timespanSeconds = (currDateTime.getTime() - @connectDateTime.getTime()) / 1000
            timespanHours = +((timespanSeconds / 3600).toFixed(2))
            timespanDays = Math.floor(timespanHours / 24)
            timespanFractHours = timespanHours - (timespanDays*24)
            connectDateText = @connectDateTime.toUTCString()
            respondFunc("Uptime = #{timespanDays} days, #{timespanFractHours.toFixed(2)} hours  (Since #{connectDateText})")
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
            commandsText += 'galaxy?  ---  What is the name of my galaxy?\n'
            commandsText += 'status?  ---  What is the status of my galaxy?\n'
            commandsText += 'round?  ---  How many rounds did my galaxy run yet?\n'
            commandsText += 'ticks?  ---  See "round?"\n'
            commandsText += 'players?  ---  How many players of my galaxy are currently online (on the channel)?\n'
            commandsText += 'users?  ---  How many players are currently online (on the channel)?\n'
            commandsText += 'uptime  ---  Prints you my time of operation\n'
            commandsText += 'version  ---  Prints you my version info\n'
            commandsText += 'help  ---  Prints you this help (in the query)\n'
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

    _sendModeSettingToIrcChannel: (channelName, modesExpression, additionalArgs...) ->
        @client.send('MODE', channelName, modesExpression, additionalArgs...);

    _respondToIrcViaCTCP: (receiverNick, ctcpCommand, responseText) ->
        ctcpText = "#{ctcpCommand} #{responseText}"
        @client.ctcp(receiverNick, 'notice', ctcpText)  # Send notice for a reply to command

    _respondToIrcQuery: (receiverNick, messageText) ->
        @client.say(receiverNick, messageText)

    _respondToIrcChannel: (channelName, receiverNick, messageText) ->
        fullMessageText = "@#{receiverNick}:  #{messageText}"
        @client.say(channelName, fullMessageText)
        # Mirror response to web channel
        @_sendMessageToWebChannel(channelName, @nickName, fullMessageText) if @_isChannelMaster(channelName)


    #
    # BotChannel handling
    #

    handleWebChannelJoin: (botChannel, isMasterBot) ->
        joinDeferred = Q.defer()
        ircChannelName = botChannel.getIrcChannelName()
        ircChannelPassword = botChannel.getIrcChannelPassword() or null

        # Store channel data
        @botChannelList[ircChannelName] = botChannel
        @masterChannelList[ircChannelName] = isMasterBot

        # Join IRC channel
        log.info "Joining bot '#{@nickName}' to channel #{ircChannelName} " +
                 "(As master: #{isMasterBot}, password: #{(ircChannelPassword or '<none>')})..."

        joinExpression = ircChannelName
        joinExpression += ' ' + ircChannelPassword if ircChannelPassword?

        @client.join joinExpression, =>
            # Set channel modes
            if ircChannelName.indexOf(Config.IRC_NONGAME_CHANNEL_PREFIX) is 0
                @_sendModeSettingToIrcChannel(ircChannelName, '+s')  # Set to secret
            if ircChannelPassword?
                @_sendModeSettingToIrcChannel(ircChannelName, '+k', ircChannelPassword)  # Set channel password

            # Resolve join
            joinDeferred.resolve()

        return joinDeferred.promise

    handleWebChannelLeave: (botChannel) ->
        partDeferred = Q.defer()
        ircChannelName = botChannel.getIrcChannelName()
        delete @botChannelList[ircChannelName]
        delete @masterChannelList[ircChannelName]
        # Part from IRC channel
        log.info "Removing bot '#{@nickName}' from channel #{ircChannelName}..."
        @client.part ircChannelName, Config.BOT_LEAVE_MESSAGE, ->
            partDeferred.resolve()
        return partDeferred.promise

    handleWebChannelMasterNomination: (botChannel) ->
        ircChannelName = botChannel.getIrcChannelName()
        if @botChannelList[ircChannelName]?
            @masterChannelList[ircChannelName] = true

    handleWebClientMessage: (channelName, senderIdentity, rawMessage) ->
        clientNick = senderIdentity.getName()
        messageText = "<#{clientNick}>: #{rawMessage}"
        @client.say(channelName, messageText)
        # Mirror to web channel, if no other bot (the master) is triggering the message though observing
        @_sendMessageToWebChannel(channelName, @nickName, messageText) if @_isChannelMaster(channelName)

    isWebChannelMaster: (botChannel) ->
        ircChannelName = botChannel.getIrcChannelName()
        return @_isChannelMaster(ircChannelName)

    _isChannelMaster: (channelName) ->
        return @masterChannelList[channelName] or false



# Export class
module.exports = SchizoBot

