
class this.Translation

    # English translated texts
    TEXTS_EN = {
        'msg.channel_joined': 'Joined $channel$'
        'msg.initial_channel_topic': 'Channel topic: $topic$'
        'msg.new_channel_topic.authorless': 'New channel topic: $topic$'
        'msg.new_channel_topic.authored': '$author$ set new channel topic: $topic$'
    }

    # German translated texts
    TEXTS_DE = {
        'msg.channel_joined': 'Channel \'$channel$\' beigetreten'
        'msg.initial_channel_topic': 'Channel-Thema: $topic$'
        'msg.new_channel_topic.authorless': 'Ein neues Channel-Thema wurde gesetzt: $topic$'
        'msg.new_channel_topic.authored': '$author$ hat ein neues Channel-Thema gesetzt: $topic$'
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
