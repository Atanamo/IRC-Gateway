
###
root = exports ? this       # Define a root compatible to browser or framework scope

root.ChatController = class ChatController
    # Class definition goes here...
###

class this.ChatController
    constructor: (@serverIP, @serverPort, @instanceData) ->
        @bindGuiEvents()

    bindGuiEvents: ->
        $('#chat_form').submit @handleGuiMessageSubmit


    start: ->
        @socket = io.connect("#{@serverIP}:#{@serverPort}")

        @socket.on 'connect', @handleServerConnect      # Build-in event
        @socket.on 'welcome', @handleServerWelcome
        @socket.on 'message', @handleMessageReceive


    handleServerConnect: =>
        $('#messages').html('')

        @guiAddChannelMessage
            msg: 'Connection established!'

    handleServerWelcome: (text) =>
        @guiAddChannelMessage
            msg: text


    handleMessageReceive: (data) =>
        @guiAddChannelMessage data


    handleGuiMessageSubmit: (e) =>
        e.preventDefault()
        messageText = $('#chat_input').val().trim()
        channel = 'galaxy_test'     #todo: take channel from current tab

        if messageText != ''
            @socket.emit 'message#' + channel, messageText

    guiAddChannelMessage: ({channel, sender, msg}) ->
        sender ?= 'SYS'

        switch sender.toString()
            when @instanceData.id
                $('#messages').append('<li style="font-weight:bold;">' + msg + " (#{channel})" + '</li>')
                $('#chat_input').val('')
            when 'SYS'
                $('#messages').append('<li style="font-style:italic;">' + msg + '</li>')
            else
                $('#messages').append('<li>' + msg + " (#{channel})" + '</li>')

