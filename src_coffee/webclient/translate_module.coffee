
class this.Translation

    # English translated texts
    TEXTS_EN = {
        'msg.server_connection_lost': 'Error: Lost connection to server! Waiting for reconnect...'
        'msg.channel_joined': 'Joined $channel$'
        'msg.initial_channel_topic': 'Channel topic: $topic$'
        'msg.new_channel_topic.authorless': 'New channel topic: $topic$'
        'msg.new_channel_topic.authored': '$author$ set new channel topic: $topic$'
        'msg.user_changed_name': '$user$ changes his name to $new_name$'
        'msg.user_joined_channel': '$user$ joined the channel'
        'msg.user_left_channel.part.reasoned': '$user$ left the channel, reason: $reason$'
        'msg.user_left_channel.part.reasonless': '$user$ left the channel'
        'msg.user_left_channel.quit.reasoned': '$user$ has quit, message: $reason$'
        'msg.user_left_channel.quit.reasonless': '$user$ has quit'
        'msg.user_kicked_from_channel': '$user$ has been kicked from channel by $actor$, reason: $reason$'
        'msg.user_killed_from_server': '$user$ has been kicked from server by $actor$, reason: $reason$'
        'msg.user_list_changed': 'The list of users has changed because of an unknown event for user $user$'
        'msg.actor_changed_a_mode': '$actor$ set channel mode $mode_event$'
        'info.current_number_of_players': 'Players online'
        'info.start_of_chat_history': 'Start of chat history ($start$ - $end$)'
        'info.end_of_chat_history': 'End of chat history ($start$ - $end$)'
        'info.unknown': 'unknown'
    }

    # German translated texts
    TEXTS_DE = {
        'msg.server_connection_lost': 'Fehler: Verbindung zum Server verloren! Warten auf Reconnect...'
        'msg.channel_joined': 'Channel \'$channel$\' beigetreten'
        'msg.initial_channel_topic': 'Channel-Thema: $topic$'
        'msg.new_channel_topic.authorless': 'Ein neues Channel-Thema wurde gesetzt: $topic$'
        'msg.new_channel_topic.authored': '$author$ hat ein neues Channel-Thema gesetzt: $topic$'
        'msg.user_changed_name': '$user$ nennt sich nun $new_name$'
        'msg.user_joined_channel': '$user$ ist dem Channel beigetreten'
        'msg.user_left_channel.part.reasoned': '$user$ hat den Channel verlassen, Grund: $reason$'
        'msg.user_left_channel.part.reasonless': '$user$ hat den Channel verlassen'
        'msg.user_left_channel.quit.reasoned': '$user$ ist offline gegangen: $reason$'
        'msg.user_left_channel.quit.reasonless': '$user$ ist offline gegangen'
        'msg.user_kicked_from_channel': '$user$ wurde von $actor$ aus dem Channel gekickt, Grund: $reason$'
        'msg.user_killed_from_server': '$user$ wurde von $actor$ vom Server geworfen, Grund: $reason$'
        'msg.user_list_changed': 'Die Userliste hat sich wegen einem Ereignis zu Benutzer $user$ aktualisiert'
        'msg.actor_changed_a_mode': '$actor$ setzt Channel-Modus: $mode_event$'
        'info.current_number_of_players': 'Spieler online'
        'info.start_of_chat_history': 'Beginn des Chatverlaufs ($start$ - $end$)'
        'info.end_of_chat_history': 'Ende des Chatverlaufs ($start$ - $end$)'
        'info.unknown': 'Unbekannt'
    }

    # Currently used translations
    localTexts = TEXTS_EN


    # Returns the translations for a text with given key and replaces placeholders by given data
    @get: (key, data) ->
        text = localTexts[key] or ''

        if data?
            for name, val of data
                text = text.replace("$#{name}$", val)

        return text

    # Returns the translations for the given server message
    @getForServerMessage: (message) ->
        # TODO
        # Create key from message (all lower case, spaces replaced by underscores, prefixed);
        # fallback to original message, if translation cannot be found


    # Returns the browser language code
    @getLangCode: ->
        return navigator.language or navigator.userLanguage

    # Sets up the translations to use by browser language
    @setup: ->
        langCode = @getLangCode()

        if langCode is 'de'
            localTexts = TEXTS_DE
        else
            localTexts = TEXTS_EN


# Setup the Translations
Translation.setup()
