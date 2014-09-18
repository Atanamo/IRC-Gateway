
# Controller class to handle communication with server
class this.ChatController

    socketHandler: null

    serverIP: ''
    serverPort: 0
    instanceData: {}

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
        channel = 'galaxy_test'     #todo: take channel from current tab

        if messageText != ''
            @socketHandler.sendMessage(channel, messageText)

    _handleGuiTabClick: (event) =>
        tabHeader = $(event.currentTarget)

        # Jump to referenced tab page in viewport
        window.location = '#' + tabHeader.data('id')

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

    handleChannelMessage: ({channel, sender, msg}) ->
        tabPage = $('#' + @_getChannelTabID(channel))
        @_appendMessageToTab(tabPage, {sender, msg})

    handleChannelJoined: (channel) =>
        tabID = @_getChannelTabID(channel)
        tabSkeleton = @ui.tabPageSkeleton.clone()
        tabSkeleton.attr('id', tabID)

        htmlTabHeader = "<li data-id=\"#{tabID}\">#{channel}</li>"

        @ui.tabsystemViewport.append(tabSkeleton)
        @ui.tabsystemHeaderList.append(htmlTabHeader)
        @_updateGuiBindings()

        #$('#' + tabID + ' .chatMessages').html('CHANNEL JOINED: ' + channel)
        @_appendMessageToTab($('#' + tabID), sender: 'CHANNEL JOINED', msg: channel)


    #
    # Helper methods
    #

    _getChannelTabID: (channel) ->
        'tabPage_' + channel

    _appendMessageToTab: (tabPage, {sender, msg}) ->
        if sender?.toString() == @instanceData.id
            dataValue = 'own'
            @ui.chatInput.val('')
        else
            dataValue = 'external'

        messagesElem = tabPage.find(@gui.tabPagesMessages)
        messagesElem.append("<li data-item=\"#{dataValue}\">#{sender}: #{msg}</li>")


