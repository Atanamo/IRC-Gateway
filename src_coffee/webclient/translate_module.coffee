
class this.Translation

    # English translated texts
    TEXTS_EN = {
        'msg.channel_joined': 'Joined $channel$'
        'msg.initial_channel_topic': 'Channel topic: $topic$'
        'msg.new_channel_topic.authorless': 'New channel topic: $topic$'
        'msg.new_channel_topic.authored': '$author$ set new channel topic: $topic$'
        'msg.user_changed_name': '$user$ changes his name to $new_name$'
        'msg.user_joined_channel': '$user$ joined the channel'
        'msg.user_left_channel.part.reasoned': '$user$ left the channel, reason: $reason$'
        'msg.user_left_channel.part.reasonless': '$user$ left the channel'
        'msg.user_left_channel.quit.reasoned': '$user$ has quit, message: $reason$'
        'msg.user_left_channel.part.reasonless': '$user$ has quit'
    }

    # German translated texts
    TEXTS_DE = {
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
