
# Controller class to handle communication with server
class this.ChatController

    socketHandler: null

    CHANNEL_NAME_MIN_LENGTH = 4
    CHANNEL_NAME_MAX_LENGTH = 20
    CHANNEL_PASSWORD_MIN_LENGTH = 5

    serverIP: ''
    serverPort: 0
    instanceData: {}
    activeTabPage: null
    windowSignalTimer: null
    windowTitleBackup: ''
    windowTitleOverwrite: ''
    tabClickCallback: null
    isInVisibleContext: true
    isSignalizingMessagesToWindow: false

    gui:
        multilangContents: '*[data-content]'
        channelCreateForm: '#channelCreateForm'
        channelNameInput: '#channelNameInput'
        channelPasswordInput: '#channelPasswordInput'
        channelFlagPublic: '#channelFlagPublic'
        channelFlagIRC: '#channelFlagIRC'
        channelLeaveButton: '.channelLeaveButton'
        channelDeleteButton: '.channelDeleteButton'
        chatForm: '.chatForm'
        chatInput: '.chatForm .chatInput'
        tabsystemViewport: '#tabsystem .tabsystemViewport'
        tabsystemHeaderList: '#tabsystem .tabsystemHeaders'
        tabsystemHeaders: '.tabsystemHeaders li'
        tabPagesMessagesPage: '.chatMessagesContainer'
        tabPagesMessages: '.chatMessages'
        tabPagesUsersIngame: '.chatUsers.players'
        tabPagesUsersIrc: '.chatUsers.irc'
        tabPagesUsersNumberBox: '.chatUsersCount'
        tabPagesUsersNumberValue: '.chatUsersCount .value'
        tabPagesChannelNameBox: '.chatChannelName'
        tabPagesChannelNameValue: '.chatChannelName .value'
        tabPagesOfChannels: '#tabsystem .tabsystemViewport > div[data-channel]'
        tabPageServer: '#tabPageServer'
        tabPageSkeleton: '#tabPageSkeleton'
        unreadTabMarker: '.newEntriesCounter'
        mentionTabMarker: '.mentioned'
        addressTabMarker: '.addressed'

    events:
        'channelCreateForm submit': '_handleGuiChannelCreateSubmit'
        'chatForm submit': '_handleGuiMessageSubmit'
        'tabsystemHeaders click': '_handleGuiTabClick'
        'channelLeaveButton click': '_handleGuiChannelLeave'
        'channelDeleteButton click': '_handleGuiChannelDelete'


    constructor: (@serverIP, @serverPort, @instanceData, options={}) ->
        @_updateGuiBindings()
        @activeTabPage = @ui.tabPageServer
        @tabClickCallback = options.tabClickCallback
        @isSignalizingMessagesToWindow = options.signalizeMessagesToWindow

        @windowTitleBackup = top.document.title
        document.addEventListener('visibilitychange', => @_handleWindowVisibilityChange())

        @_translateMultilangContents()

    start: ->
        @socketHandler = new SocketClient(this, @serverIP, @serverPort, @instanceData)
        @socketHandler.start()

    # Sets a flag to inform the tab system, that its content is currently (not) visible because of environment constraints.
    # This info is used to show or reset markers for unread messages.
    setTabContentVisibilityInfo: (isVisible) ->
        return if @isInVisibleContext is isVisible
        @isInVisibleContext = isVisible
        @_resetNewEntryMarkOfTab(@activeTabPage) if isVisible  # Reset marker for unread messages

    _bindGuiElements: ->
        @ui = {}
        for name, selector of @gui
            @ui[name] = $(selector)

    _bindGuiEvents: ->
        for expr, handlerName of @events
            [elemName, eventName] = expr.split(" ")
            elem = @ui[elemName]
            handler = @[handlerName]

            if elem? and handler?
                handler.bind(this)
                elem.off(eventName, handler)
                elem.on(eventName, handler)

    _updateGuiBindings: ->
        @_bindGuiElements()
        @_bindGuiEvents()

    _translateMultilangContents: ->
        @ui.multilangContents.each (idx, element) =>
            textElem = $(element)
            translatedText = Translation.get(textElem.data('content'))
            textElem.text(translatedText) if translatedText


    #
    # GUI event handling
    #

    _handleWindowVisibilityChange: ->
        clearInterval(@windowSignalTimer) if @windowSignalTimer?
        top.document.title = @windowTitleBackup  # Reset window title
        @_resetNewEntryMarkOfTab(@activeTabPage)  # Reset marker for unread messages

    _handleGuiChannelCreateSubmit: (event) =>
        event.preventDefault()
        channelName = @ui.channelNameInput.val().trim()
        channelPassword = @ui.channelPasswordInput.val().trim()
        isPublic = @ui.channelFlagPublic.prop('checked') or false
        isForIrc = @ui.channelFlagIRC.prop('checked') or false

        return unless channelName

        @socketHandler.sendChannelJoinRequest(channelName, channelPassword, isPublic, isForIrc)

    _handleGuiChannelDelete: (event) =>
        event.preventDefault()
        channel = @activeTabPage?.data('channel') or ''
        @socketHandler.sendChannelDeleteRequest(channel)

    _handleGuiChannelLeave: (event) =>
        event.preventDefault()
        channel = @activeTabPage?.data('channel') or ''
        @socketHandler.sendChannelLeaveRequest(channel)

    _handleGuiMessageSubmit: (event) =>
        event.preventDefault()
        channel = @activeTabPage?.data('channel') or ''
        @socketHandler.sendMessage(channel)

    _handleGuiTabClick: (event) =>
        tabHeader = $(event.currentTarget)
        tabID = tabHeader.data('id')

        # Hide last active tab
        @activeTabPage.hide()

        # Remember active tab
        @activeTabPage = @_getTabPage(tabID)

        # Highlight tab header
        @ui.tabsystemHeaders.removeClass('active')
        tabHeader.addClass('active')

        # Show new active tab
        @activeTabPage.show()

        # Focus input field
        @activeTabPage.find(@gui.chatInput).focus()

        # Reset marker for unread messages
        @_resetNewEntryMarkOfTab(@activeTabPage)

        # Scroll to bottom (Hidden tabs cannot be scrolled)
        @_scrollToBottomOfTab(@activeTabPage)

        # Invoke callback, if existing
        @tabClickCallback?(@activeTabPage)


    #
    # Socket client handling
    #

    handleServerDisconnect: ->
        # Inform all channel tabs and clear user lists
        informText = Translation.get('msg.server_connection_lost')
        @ui.tabPagesOfChannels.each (idx, domNode) =>
            tabPage = $(domNode)
            @_appendNoticeToTab(tabPage, null, 'error', informText)
            @_clearUserListOfTab(tabPage)
            @_addNewEntryMarkToTab(tabPage, {force: true}, informText) if idx is 0

    handleServerMessage: (msg, isError=false) ->
        messageType = 'log'
        messageType = 'error' if isError
        tabPage = @ui.tabPageServer
        @_appendNoticeToTab(tabPage, null, messageType, msg)
        @_addNewEntryMarkToTab(tabPage)

    handleChannelMessage: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)
        @_appendMessageToTab(tabPage, timestamp, data)
        @_addNewEntryMarkToTab(tabPage, data, data.text)

    handleChannelNotice: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)
        @_appendNoticeToTab(tabPage, timestamp, 'notice', data.text, true)
        @_addNewEntryMarkToTab(tabPage, data, data.text)

    handleChannelHistoryMark: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)
        startTime = @_getLocalizedDateTime(data.start)
        endTime = @_getLocalizedDateTime(data.end)

        if data.isStart
            infoText = Translation.get('info.start_of_chat_history', start: startTime, end: endTime)
        else
            infoText = Translation.get('info.end_of_chat_history', start: startTime, end: endTime)

        tabPage.toggleClass('receiving-history', data.isStart)     # Set class while adding history entries
        @_appendHistoryMarkerToTab(tabPage, timestamp, infoText)
        @_movePreHistoryEntriesOfTab(tabPage) unless data.isStart  # Move entries sent before history to position after history

    handleChannelJoined: (channel, timestamp, data) ->
        tabID = @_getChannelTabID(channel)
        tabPage = @_getChannelTabPage(channel)
        channelTitle = data?.title or channel
        ircChannelName = data.ircChannelName or null
        isNewTab = (tabPage?.length is 0)

        if isNewTab
            # Set up tab parts
            htmlTabHeader = "<li data-id=\"#{tabID}\">#{channelTitle}</li>"
            tabSkeleton = @ui.tabPageSkeleton.clone()
            tabSkeleton.attr('id', tabID)
            tabSkeleton.attr('data-channel', channel)

            # Add tab to DOM
            @ui.tabsystemViewport.append(tabSkeleton)
            @ui.tabsystemHeaderList.append(htmlTabHeader)
            @_updateGuiBindings()

            # Get new tab
            tabPage = @_getChannelTabPage(channel)
            tabPage.hide()

            # Remove invalid buttons
            unless data.isCustom
                tabPage.find(@gui.channelLeaveButton).remove()
            unless data.creatorID is @instanceData?.userID
                tabPage.find(@gui.channelDeleteButton).remove()

        # Print join message to new tab and server tab
        noticeText = Translation.get('msg.channel_joined', channel: channelTitle)
        @_appendNoticeToTab(tabPage, timestamp, 'initial_join', noticeText)
        @handleServerMessage(noticeText)

        # Set IRC channel name
        @_setIrcChannelNameToTab(tabPage, ircChannelName) if ircChannelName?

        # Reset the form for channel creation/joining
        @ui.channelCreateForm[0]?.reset?()

        return isNewTab

    handleChannelLeft: (channel, timestamp) ->
        tabID = @_getChannelTabID(channel)

        # Remove tab from DOM
        @ui.tabsystemViewport.find("##{tabID}").remove()
        @ui.tabsystemHeaderList.find("[data-id=#{tabID}]").remove()
        @_updateGuiBindings()

        # Show server tab
        @ui.tabsystemHeaders[0]?.click()

    handleChannelUserList: (channel, clientList) ->
        tabPage = @_getChannelTabPage(channel)
        @_clearUserListOfTab(tabPage)
        for identityData in clientList
            @_appendUserEntryToTab(tabPage, identityData.name, identityData.title, identityData.isIrcClient)

    handleChannelUserNumber: (channel, clientsNumber) ->
        tabPage = @_getChannelTabPage(channel)
        @_setUserNumberToTab(tabPage, clientsNumber)


    handleChannelTopic: (channel, timestamp, {topic, author, isInitial}) ->
        tabPage = @_getChannelTabPage(channel)

        if isInitial
            noticeText = Translation.get('msg.initial_channel_topic', topic: topic)
            @_appendNoticeToTab(tabPage, timestamp, 'topic', noticeText)
        else
            if author?
                noticeText = Translation.get('msg.new_channel_topic.authored', topic: topic, author: author)
            else
                noticeText = Translation.get('msg.new_channel_topic.authorless', topic: topic)

            @_appendNoticeToTab(tabPage, timestamp, 'topic', noticeText)

        @_addNewEntryMarkToTab(tabPage)

    handleChannelUserChange: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)

        noticeText = ''
        detailsData = data.details or {}
        userName = data.user
        reasonText = detailsData.reason

        switch data.action
            when 'rename'
                newName = detailsData.newName
                newName = "-#{Translation.get('info.unknown')}-" unless newName?
                noticeText = Translation.get('msg.user_changed_name', user: userName, new_name: newName)

            when 'join'
                noticeText = Translation.get('msg.user_joined_channel', user: userName)

            when 'part', 'quit'
                if reasonText?
                    noticeText = Translation.get("msg.user_left_channel.#{data.action}.reasoned", user: userName, reason: reasonText)
                else
                    noticeText = Translation.get("msg.user_left_channel.#{data.action}.reasonless", user: userName)

            when 'kick'
                actorName = detailsData.actor 
                actorName = "-#{Translation.get('info.unknown')}-" unless actorName?
                reasonText = "-#{Translation.get('info.unknown')}-" unless reasonText?
                noticeText = Translation.get('msg.user_kicked_from_channel', user: userName, actor: actorName, reason: reasonText)

            when 'kill'
                reasonText = "-#{Translation.get('info.unknown')}-" unless reasonText?
                noticeText = Translation.get('msg.user_killed_from_server', user: userName, reason: reasonText)

            else
                userName = "-#{Translation.get('info.unknown')}-" unless userName?
                noticeText = Translation.get('msg.user_list_changed', user: userName)

        @_appendNoticeToTab(tabPage, timestamp, 'user_change', noticeText)
        @_addNewEntryMarkToTab(tabPage, data, noticeText)

    handleChannelModeChange: (channel, timestamp, {actor, mode, enabled, argument}) ->
        actor = "-#{Translation.get('info.unknown')}-" unless actor?
        modeText = if enabled then "+#{mode}" else "-#{mode}"
        modeEvent = if argument? then "#{modeText} #{argument}" else modeText
        noticeText = Translation.get('msg.actor_changed_a_mode', actor: actor, mode_event: modeEvent)

        tabPage = @_getChannelTabPage(channel)
        @_appendNoticeToTab(tabPage, timestamp, 'mode_change', noticeText)
        @_addNewEntryMarkToTab(tabPage)


    #
    # Helper methods
    #

    _getChannelTabID: (channel) ->
        'tabPage_' + channel

    _getChannelTabPage: (channel) ->
        tabID = @_getChannelTabID(channel)
        return @_getTabPage(tabID)

    _getTabPage: (tabID) ->
        return $('#' + tabID)

    _setUserNumberToTab: (tabPage, userNumber) ->
        tabPage.find(@gui.tabPagesUsersNumberBox).show()
        tabPage.find(@gui.tabPagesUsersNumberValue).html(userNumber)

    _setIrcChannelNameToTab: (tabPage, ircChannelName) ->
        tabPage.find(@gui.tabPagesChannelNameBox).show()
        tabPage.find(@gui.tabPagesChannelNameValue).html(ircChannelName)

    _clearUserListOfTab: (tabPage) ->
        tabPage.find(@gui.tabPagesUsersIngame).empty()
        tabPage.find(@gui.tabPagesUsersIrc).empty()

    _appendUserEntryToTab: (tabPage, shortName, fullName, isIrcUser) ->
        # Build new list item
        itemElem = $('<li/>')
        itemElem.attr('title', fullName)
        itemElem.text(shortName)

        # Append item to list
        if isIrcUser
            messagesElem = tabPage.find(@gui.tabPagesUsersIrc)
        else
            messagesElem = tabPage.find(@gui.tabPagesUsersIngame)
        messagesElem.append(itemElem)

    _appendMessageToTab: (tabPage, timestamp, {text, sender, inlineAuthor, isOwn, isMentioningOwn, isAddressingOwn}) ->
        styleClasses = 'message'

        if isOwn
            styleClasses += ' own'
            tabPage.find(@gui.chatInput).val('')
        else
            styleClasses += ' external'

        if isAddressingOwn
            styleClasses += ' addressing'
        else if isMentioningOwn
            styleClasses += ' mentioning'

        options =
            styleClasses: styleClasses
            mainAuthor: sender
            inlineAuthor: inlineAuthor

        @_appendEntryToTab(tabPage, timestamp, 'message', text, options)
        @_scrollToBottomOfTab(tabPage)

    _appendNoticeToTab: (tabPage, timestamp, noticeType, noticeText, isSentByUser=false) ->
        noticeText = "** #{noticeText}" unless tabPage is @ui.tabPageServer  # Prefix notices except for server tab
        timestamp = (new Date()).getTime() unless timestamp?
        styleClasses = 'notice'
        styleClasses += ' fromUser' if isSentByUser
        styleClasses += ' error' if noticeType is 'error'

        @_appendEntryToTab(tabPage, timestamp, 'server', noticeText, styleClasses: styleClasses)
        @_scrollToBottomOfTab(tabPage)

    _appendHistoryMarkerToTab: (tabPage, timestamp, markerNoticeText) ->
        markerText = "----- #{markerNoticeText} -----"
        @_appendEntryToTab(tabPage, null, 'marker', markerText, styleClasses: 'marker')
        @_scrollToBottomOfTab(tabPage)

    _appendEntryToTab: (tabPage, entryTimestamp, entryType, entryText, options) ->
        # Build new list item
        itemElem = $('<li/>')
        itemElem.attr('data-item', entryType)
        itemElem.addClass(options.styleClasses)
        itemElem.addClass('historical') if entryType isnt 'marker' and @_isHistoryReceivingTab(tabPage)

        if entryTimestamp?
            spanElem = $('<span/>').addClass('time')
            spanElem.text("[#{@_getLocalizedTime(entryTimestamp)}]")
            spanElem.attr('title', @_getLocalizedDateTime(entryTimestamp))
            itemElem.append(spanElem)
            itemElem.append(' ')

        if options.mainAuthor?
            spanElem = $('<span/>').addClass('name')
            spanElem.text(options.mainAuthor)
            itemElem.append(spanElem)

            if options.inlineAuthor?
                inlineSpanElem = $('<span/>').addClass('virtualName')
                inlineSpanElem.text("<#{options.inlineAuthor}>")
                spanElem.append(' ')
                spanElem.append(inlineSpanElem)

            spanElem.append(': ')

        spanElem = $('<span/>').addClass('content')
        spanElem.text(entryText)
        itemElem.append(spanElem)

        # Append item to list
        messagesElem = tabPage.find(@gui.tabPagesMessages)
        messagesElem.append(itemElem)

    _movePreHistoryEntriesOfTab: (tabPage) ->
        messagesElem = tabPage.find(@gui.tabPagesMessages)

        # Find entries before history marker
        entriesElems = messagesElem.find('> *')
        entriesElems = entriesElems.not('li[data-item="marker"] ~li').not('[data-item="marker"]')

        # Remove entries from DOM
        entriesElems.remove()

        # Append entries to end of messages list
        messagesElem.append(entriesElems)


    _addNewEntryMarkToTab: (tabPage, notifyData={}, notifyText=null) ->
        tabID = tabPage.attr('id')
        isReceivingHistory = @_isHistoryReceivingTab(tabPage)

        # Ignore historical messages
        return if isReceivingHistory

        # Mark tab for new message
        if document.hidden or not @isInVisibleContext or tabID isnt @activeTabPage.attr('id')
            # Add/increment marker for unread messages
            tabHeader = @ui.tabsystemHeaderList.find("[data-id=#{tabID}]")
            spanElem = tabHeader.find(@gui.unreadTabMarker)

            if spanElem.length is 0
                spanElem = $('<span/>').addClass(@gui.unreadTabMarker.replace(/\./g, ''))
                tabHeader.append(spanElem)

            lastText = spanElem.text()
            lastCount = lastText.replace(/[^0-9]/g, '')
            lastCount++
            spanElem.text(lastCount)

            # Add markers for mentioning and addressing
            if notifyData.force or notifyData.isMentioningOwn
                tabHeader.addClass(@gui.mentionTabMarker.replace(/\./g, ''))
            if notifyData.isAddressingOwn
                tabHeader.addClass(@gui.addressTabMarker.replace(/\./g, ''))

        # May signalize message in window title
        @_checkForSignalizingMessageToWindow(notifyData, notifyText)

    _resetNewEntryMarkOfTab: (tabPage) ->
        tabID = tabPage.attr('id')
        tabHeader = @ui.tabsystemHeaderList.find("[data-id=#{tabID}]")

        # Remove unread marker
        spanElem = tabHeader.find(@gui.unreadTabMarker)
        spanElem.remove()

        # Remove mention markers
        tabHeader.removeClass(@gui.mentionTabMarker.replace(/\./g, ''))
        tabHeader.removeClass(@gui.addressTabMarker.replace(/\./g, ''))

    _checkForSignalizingMessageToWindow: (notifyData={}, notifyText='') ->
        return unless @isSignalizingMessagesToWindow
        return unless document.visibilityState?  # Check browser support for visibility API
        return unless document.hidden  # Cancel, if window is visible

        # Calculate sum of unread messages
        unreadMessagesCount = 0
        markerElems = @ui.tabsystemHeaderList.find(@gui.unreadTabMarker)
        markerElems.each (idx, item) ->
            unreadMessagesCount += +($(item).text().replace(/[^0-9]/g, ''))

        # Set window title
        addressMarksExists = @ui.tabsystemHeaderList.find(@gui.addressTabMarker).length > 0
        addressMark = if notifyData.isAddressingOwn or addressMarksExists then '*' else ''
        @windowTitleOverwrite = "[#{addressMark}#{unreadMessagesCount}#{addressMark}] #{@windowTitleBackup}"
        top.document.title = @windowTitleOverwrite

        # May let window title blink
        if notifyData.force or notifyData.isMentioningOwn
            blinkFunc = =>
                top.document.title = if top.document.title is @windowTitleOverwrite then "\"#{notifyText}\"" else @windowTitleOverwrite

            clearInterval(@windowSignalTimer) if @windowSignalTimer?
            @windowSignalTimer = setInterval(blinkFunc, 800)

    _isHistoryReceivingTab: (tabPage) ->
        return tabPage.hasClass('receiving-history')

    _scrollToBottomOfTab: (tabPage) ->
        pageElem = tabPage.find(@gui.tabPagesMessagesPage)
        scrollOffset = pageElem.prop('scrollHeight')
        pageElem.scrollTop(scrollOffset)

    _getLocalizedTime: (timestamp) ->
        date = new Date(timestamp)
        return date.toLocaleTimeString()

    _getLocalizedDateTime: (timestamp) ->
        date = new Date(timestamp)
        return date.toLocaleString()
