
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
        sender = 'Server'
        @_appendMessageToTab(tabPage, {sender, msg})

    handleChannelMessage: (data) ->
        channel = data.channel
        tabPage = @_getChannelTabPage(channel)
        @_appendMessageToTab(tabPage, data)

    handleChannelJoined: (channel) =>
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
        #$('#' + tabID + ' .chatMessages').html('CHANNEL JOINED: ' + channel)
        @_appendMessageToTab(tabPage, sender: 'CHANNEL JOINED', msg: channel)


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

    _appendMessageToTab: (tabPage, {sender, msg, isOwn}) ->
        if isOwn
            dataValue = 'own'
            @ui.chatInput.val('')
        else
            dataValue = 'external'

        messagesElem = tabPage.find(@gui.tabPagesMessages)
        messagesElem.append("<li data-item=\"#{dataValue}\">#{sender}: #{msg}</li>")


