
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
        tabsystemViewport: '#chatsystem .tabsystemViewport'
        tabsystemHeaderList: '#chatsystem .tabsystemHeaders'
        tabsystemHeaders: '.tabsystemHeaders li'
        tabPagesMessages: '.chatMessages'
        tabPageSkeleton: '#tabPageSkeleton'
        tabPageServer: '#tabPageServer'

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

    handleServerMessage: (msg) ->
        tabPage = @ui.tabPageServer
        @_appendNoticeToTab(tabPage, null, 'log', msg)

    handleChannelMessage: (channel, data) ->
        tabPage = @_getChannelTabPage(channel)
        @_appendMessageToTab(tabPage, data)

    handleChannelJoined: (channel) ->
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
        @_appendNoticeToTab(tabPage, null, 'initial_join', "Joined #{channel}")  # TODO: Translated notice

    handleChannelTopic: (channel, timestamp, {topic, author, isInitial}) ->
        # TODO: Translated notices
        tabPage = @_getChannelTabPage(channel)

        if isInitial
            @_appendNoticeToTab(tabPage, timestamp, 'topic', "Channel topic: #{topic}")
        else
            if author?
                notice = "#{author} set new channel topic: #{topic}"
            else
                notice = "New channel topic: #{topic}"

            @_appendNoticeToTab(tabPage, timestamp, 'topic', notice)


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

    _appendMessageToTab: (tabPage, {timestamp, sender, msg, isOwn}) ->
        if isOwn
            dataValue = 'own'
            @ui.chatInput.val('')
        else
            dataValue = 'external'

        @_appendEntryToTab(tabPage, timestamp, dataValue, msg, sender)

    _appendNoticeToTab: (tabPage, timestamp, noticeType, noticeText) ->
        @_appendEntryToTab(tabPage, timestamp, "server", noticeText)

    _appendEntryToTab: (tabPage, entryTimestamp, entryDataValue, entryText, entryAuthor) ->
        unless entryTimestamp?
            entryTimestamp = (new Date()).getTime()
            console.warn 'Missing timestamp for new entry:', entryText  # TODO: Remove logging
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

    _getLocalizedTime: (timestamp) ->
        date = new Date(timestamp)
        return date.toLocaleTimeString()
