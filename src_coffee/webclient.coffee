
# Controller class to handle communication with server
class this.ChatController
    constructor: (@serverIP, @serverPort, @instanceData) ->
        @bindGuiEvents()

    bindGuiEvents: ->
        $('#chat_form').submit @handleGuiMessageSubmit
        @updateGuiListeners()

    updateGuiListeners: ->
        $('.tabsystemHeaders li').click @handleGuiTabClick
        # Todo: May unbind old listeners


    start: ->
        @socket = io.connect("#{@serverIP}:#{@serverPort}")

        @socket.on 'connect', @handleServerConnect      # Build-in event
        @socket.on 'welcome', @handleServerWelcome
        @socket.on 'message', @handleMessageReceive
        @socket.on 'joined', @handleChannelJoined


    handleServerConnect: =>
        #$('#messages').html('')

        @guiAddChannelMessage
            msg: 'Connection established!'

    handleServerWelcome: (text) =>
        @guiAddChannelMessage
            msg: text


    handleMessageReceive: (data) =>
        @guiAddChannelMessage data

    handleChannelJoined: (channel) =>
        tabID = @_getChannelTabID(channel)
        tabSkeleton = $('#tabPageSkeleton').clone()
        tabSkeleton.attr('id', tabID)

        htmlTabHeader = "<li data-id=\"#{tabID}\">#{channel}</li>"

        $('#chatsystem .tabsystemViewport').append(tabSkeleton)
        $('#chatsystem .tabsystemHeaders').append(htmlTabHeader)

        $('#' + tabID + ' .chatMessages').html('CHANNEL JOINED: ' + channel)
        @updateGuiListeners()


    handleGuiMessageSubmit: (event) =>
        event.preventDefault()
        messageText = $('#chat_input').val().trim()
        channel = 'galaxy_test'     #todo: take channel from current tab

        if messageText != ''
            @socket.emit 'message#' + channel, messageText

    handleGuiTabClick: (event) =>
        tabHeader = $(event.currentTarget)

        # Jump to referenced tab page in viewport
        window.location = '#' + tabHeader.data('id')

        # Highlight tab header
        $('.tabsystemHeaders li').removeClass('active')
        tabHeader.addClass('active')


    guiAddChannelMessage: ({channel, sender, msg}) ->
        if channel? and sender?
            tabPage = $('#' + @_getChannelTabID(channel))
        else
            tabPage = $('#tabPageServer')
            sender = 'Server'

        if sender?.toString() == @instanceData.id
            dataValue = 'own'
            $('#chat_input').val('')
        else
            dataValue = 'external'

        tabPage.find('.chatMessages').append("<li data-item=\"#{dataValue}\">#{sender}: #{msg}</li>")



    ###
        Helper methods
    ###

    _getChannelTabID: (channel) ->
        'tabPage_' + channel