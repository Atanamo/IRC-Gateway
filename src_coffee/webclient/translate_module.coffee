
class this.Translation

    # English translated texts
    TEXTS_EN = {
        'server_msg.invalid_input': 'Invalid input!'
        'server_msg.illegal_length_of_channel_name': 'The requested channel name is too short or too long!'
        'server_msg.channel_password_too_short': 'The requested channel password is too short!'
        'server_msg.channel_password_too_long': 'The requested channel password is too long!'
        'server_msg.invalid_user_data': 'Invalid user data!'
        'server_msg.unknown_user': 'Unknown user!'
        'server_msg.invalid_token': 'Invalid token!'
        'server_msg.reached_channel_limit': 'You reached the limit for self-created channels! Please delete other channels first.'
        'server_msg.wrong_password': 'Wrong channel password!'

        'manage_msg.loading_start': 'Loading...'
        'manage_msg.connect_success': 'Connection established!'
        'manage_msg.connect_error': 'Connection error: $error$'
        'manage_msg.connect_lost': 'Connection lost! Server may quit'
        'manage_msg.auth_start': 'Authenticating...'
        'manage_msg.auth_success': 'Authentication successful!'
        'manage_msg.auth_failed': 'Authentication failed! $reason$'
        'manage_msg.welcome_message': 'Welcome message: $message$'
        'manage_msg.channel_join_failed': 'Channel join failed! $reason$'

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

        'info.start_of_chat_history': 'Start of chat history ($start$ - $end$)'
        'info.end_of_chat_history': 'End of chat history ($start$ - $end$)'
        'info.unknown': 'unknown'

        'label.current_number_of_players': 'Players online'
        'label.irc_channel_name': 'IRC'
        'label.channel_name': 'Channel name'
        'label.channel_password': 'Channel password'
        'label.channel_flag_public': 'Hide joined users'
        'label.channel_flag_irc': 'Mirror channel to IRC'
    }

    # German translated texts
    TEXTS_DE = {
        'server_msg.invalid_input': 'Ungültige Eingaben!'
        'server_msg.illegal_length_of_channel_name': 'Der angeforderte Channel-Name ist zu kurz oder zu lang!'
        'server_msg.channel_password_too_short': 'Das angeforderte Channel-Passwort ist zu kurz!'
        'server_msg.channel_password_too_long': 'Das angeforderte Channel-Passwort ist zu lang!'
        'server_msg.invalid_user_data': 'Ungültige Benutzerdaten!'
        'server_msg.unknown_user': 'Unbekannter Benutzer!'
        'server_msg.invalid_token': 'Ungültiges Token!'
        'server_msg.reached_channel_limit': 'Du hast das Limit für selbst erstellte Channels erreicht! Lösche bitte bestehende Channels vorher.'
        'server_msg.wrong_password': 'Das Channel-Passwort ist falsch!'

        'manage_msg.loading_start': 'Initialisierung läuft...'
        'manage_msg.connect_success': 'Verbindung zum Server hergestellt!'
        'manage_msg.connect_error': 'Verbindungsabbruch: $error$'
        'manage_msg.connect_lost': 'Verbindung zum Server abgerissen! Server wurde eventuell beendet.'
        'manage_msg.auth_start': 'Anmeldung läuft...'
        'manage_msg.auth_success': 'Anmeldung erfolgreich!'
        'manage_msg.auth_failed': 'Anmeldung fehlgeschlagen! $reason$'
        'manage_msg.welcome_message': 'Willkommensnachricht: $message$'
        'manage_msg.channel_join_failed': 'Channel-Beitritt fehlgeschlagen! $reason$'

        'msg.server_connection_lost': 'Fehler: Verbindung zum Server abgerissen! Warten auf Reconnect...'
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

        'info.start_of_chat_history': 'Beginn des Chatverlaufs ($start$ - $end$)'
        'info.end_of_chat_history': 'Ende des Chatverlaufs ($start$ - $end$)'
        'info.unknown': 'Unbekannt'

        'label.current_number_of_players': 'Spieler online'
        'label.irc_channel_name': 'IRC'
        'label.channel_name': 'Channel-Name'
        'label.channel_password': 'Channel-Passwort'
        'label.channel_flag_public': 'Beigetretene User verstecken'
        'label.channel_flag_irc': 'Channel ins IRC spiegeln'
    }

    # Currently used translations
    localTexts = TEXTS_EN


    # Returns the translations for a text with given key and replaces placeholders by given data
    @get: (key, data) ->
        text = localTexts[key] or "{Missing text for key: #{key}}"

        if data?
            for name, val of data
                text = text.replace("$#{name}$", val)

        return text

    # Returns the translations for the given server message
    @getForServerMessage: (message) ->
        key_part = message.toLowerCase().replace(/[ ]/g, '_')
        text = localTexts["server_msg.#{key_part}"] or message
        return text

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
