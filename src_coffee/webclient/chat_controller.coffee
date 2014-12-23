
# Controller class to handle communication with server
class this.ChatController

    socketHandler: null

    serverIP: ''
    serverPort: 0
    instanceData: {}
    activeTabPage: null

    gui:
        chatForm: '#chat_form'
        chatInput: '#chat_input'
        tabsystemViewport: '#tabsystem .tabsystemViewport'
        tabsystemHeaderList: '#tabsystem .tabsystemHeaders'
        tabsystemHeaders: '.tabsystemHeaders li'
        tabPagesMessagesPage: '.chatMessagesContainer'
        tabPagesMessages: '.chatMessages'
        tabPagesUsers: '.chatUsers'
        tabPagesUsersNumberBox: '.chatUsersCount'
        tabPagesUsersNumberText: '.chatUsersCount .title'
        tabPagesUsersNumberValue: '.chatUsersCount .value'
        tabPagesOfChannels: '#tabsystem .tabsystemViewport > div[data-channel]'
        tabPageServer: '#tabPageServer'
        tabPageSkeleton: '#tabPageSkeleton'

    events:
        'chatForm submit': '_handleGuiMessageSubmit'
        'tabsystemHeaders click': '_handleGuiTabClick'


    constructor: (@serverIP, @serverPort, @instanceData) ->
        @_updateGuiBindings()
        @activeTabPage = @ui.tabPageServer

    start: ->
        @socketHandler = new SocketClient(this, @serverIP, @serverPort, @instanceData)
        @socketHandler.start()


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


    #
    # GUI event handling
    #

    _handleGuiMessageSubmit: (event) =>
        event.preventDefault()
        messageText = @ui.chatInput.val().trim()
        channel = @activeTabPage?.data('channel') or ''

        if messageText isnt '' and channel isnt ''
            @socketHandler.sendMessage(channel, messageText)

    _handleGuiTabClick: (event) =>
        tabHeader = $(event.currentTarget)
        tabID = tabHeader.data('id')

        # Remember active tab
        @activeTabPage = @_getTabPage(tabID)

        # Jump to referenced tab page in viewport
        window.location = '#' + tabID

        # Highlight tab header
        @ui.tabsystemHeaders.removeClass('active')
        tabHeader.addClass('active')


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

    handleServerMessage: (msg) ->
        tabPage = @ui.tabPageServer
        @_appendNoticeToTab(tabPage, null, 'log', msg)

    handleChannelMessage: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)
        @_appendMessageToTab(tabPage, timestamp, data)

    handleChannelNotice: (channel, timestamp, data) ->
        tabPage = @_getChannelTabPage(channel)
        @_appendNoticeToTab(tabPage, timestamp, 'notice', data.text)

    handleChannelJoined: (channel, timestamp) ->
        tabID = @_getChannelTabID(channel)
        tabPage = @_getChannelTabPage(channel)

        if tabPage?.length is 0
            # Set up tab parts
            htmlTabHeader = "<li data-id=\"#{tabID}\">#{channel}</li>"
            tabSkeleton = @ui.tabPageSkeleton.clone()
            tabSkeleton.attr('id', tabID)
            tabSkeleton.attr('data-channel', channel)

            # Add tab to DOM
            @ui.tabsystemViewport.append(tabSkeleton)
            @ui.tabsystemHeaderList.append(htmlTabHeader)
            @_updateGuiBindings()

            # Get new tab
            tabPage = @_getChannelTabPage(channel)

        # Print join message to tab
        noticeText = Translation.get('msg.channel_joined', channel: channel)
        @_appendNoticeToTab(tabPage, timestamp, 'initial_join', noticeText)

    handleChannelLeft: (channel, timestamp) ->
        tabID = @_getChannelTabID(channel)

        # Remove tab from DOM
        @ui.tabsystemViewport.find("##{tabID}").remove()
        @ui.tabsystemHeaderList.find("[data-id=#{tabID}]").remove()
        @_updateGuiBindings()

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


    handleChannelModeChange: (channel, timestamp, {actor, mode, enabled, argument}) ->
        actor = "-#{Translation.get('info.unknown')}-" unless actor?
        modeText = if enabled then "+#{mode}" else "-#{mode}"
        modeEvent = if argument? then "#{modeText} #{argument}" else modeText
        noticeText = Translation.get('msg.actor_changed_a_mode', actor: actor, mode_event: modeEvent)

        tabPage = @_getChannelTabPage(channel)
        @_appendNoticeToTab(tabPage, timestamp, 'mode_change', noticeText)


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

    _clearUserListOfTab: (tabPage) ->
        tabPage.find(@gui.tabPagesUsers).empty()

    _setUserNumberToTab: (tabPage, userNumber) ->
        tabPage.find(@gui.tabPagesUsersNumberBox).show()
        tabPage.find(@gui.tabPagesUsersNumberText).html(Translation.get('info.current_number_of_players'))
        tabPage.find(@gui.tabPagesUsersNumberValue).html(userNumber)

    _appendUserEntryToTab: (tabPage, shortName, fullName, isIrcUser) ->
        itemText = shortName
        itemText += ' [IRC]' if isIrcUser

        # Build new list item
        itemElem = $('<li/>')
        itemElem.attr('title', fullName)
        itemElem.text(itemText)

        # Append item to list
        messagesElem = tabPage.find(@gui.tabPagesUsers)
        messagesElem.append(itemElem)

    _appendMessageToTab: (tabPage, timestamp, {sender, text, isOwn}) ->
        if isOwn
            dataValue = 'own'
            @ui.chatInput.val('')
        else
            dataValue = 'external'

        @_appendEntryToTab(tabPage, timestamp, dataValue, text, sender)
        @_scrollToBottomOfTab(tabPage)

    _appendNoticeToTab: (tabPage, timestamp, noticeType, noticeText) ->
        noticeText = "* #{noticeText}" unless tabPage is @ui.tabPageServer  # Prefix notices except for server tab
        @_appendEntryToTab(tabPage, timestamp, 'server', noticeText)
        @_scrollToBottomOfTab(tabPage)

    _appendEntryToTab: (tabPage, entryTimestamp, entryDataValue, entryText, entryAuthor) ->
        unless entryTimestamp?
            entryTimestamp = (new Date()).getTime()
            #console.warn 'Missing timestamp for new entry:', entryText
        timeString = @_getLocalizedTime(entryTimestamp)

        # Build new list item
        itemElem = $('<li/>')
        itemElem.attr('data-item', entryDataValue)

        spanElem = $('<span/>').addClass('time')
        spanElem.text("[#{timeString}] ")
        itemElem.append(spanElem)

        if entryAuthor?
            spanElem = $('<span/>').addClass('name')
            spanElem.text(entryAuthor + ': ')
            itemElem.append(spanElem)

        spanElem = $('<span/>').addClass('content')
        spanElem.text(entryText)
        itemElem.append(spanElem)

        # Append item to list
        messagesElem = tabPage.find(@gui.tabPagesMessages)
        messagesElem.append(itemElem)

    _scrollToBottomOfTab: (tabPage) ->
        pageElem = tabPage.find(@gui.tabPagesMessagesPage)
        scrollOffset = pageElem.prop('scrollHeight')
        pageElem.scrollTop(scrollOffset)

    _getLocalizedTime: (timestamp) ->
        date = new Date(timestamp)
        return date.toLocaleTimeString()
