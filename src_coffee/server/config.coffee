
## CONFIG ##

# Bot sub config
botNickPrefix = '_Galaxy'       # Prefix for bot's nick name on IRC
botName = 'SGR GalaxyBot'       # Bot's official name
botVersion = 'v1.0'             # Bot's version number string
botLastUpdate = '2014-10-01'    # Update info for bot version

# IRC sub config
ircServerIP = 'underworld1.no.quakenet.org'
ircServerPort = 6667
ircGlobalChannel = '#sgr2'

# Main config
module.exports =

    DEBUG_ENABLED: true  # Set to true, to enable some debug output

    BOT_NICK_PATTERN: "#{botNickPrefix}<id>"                  # The nick name of the Bot on IRC, with <id> as a placeholder for the game ID
    BOT_REALNAME_PATTERN: "<name> - #{botName} <id>"          # The real name of the Bot on IRC, with <id> and <name> as placeholders for the game ID and name
    BOT_VERSION_STRING: "#{botName}, #{botVersion} " +        # The version string of the Bot, for requests on IRC
                        "(Last update: #{botLastUpdate}) " +
                        "-- Created 2014 by Atanamo"

    IRC_SERVER_IP: ircServerIP
    IRC_SERVER_PORT: ircServerPort

    IRC_CHANNEL_GLOBAL: ircGlobalChannel
    #IRC_CHANNEL_INGAME_PATTERN: '#sgr_ingame_galaxy_<id>'
    #IRC_CHANNEL_INGAME_PASSWORD: '!This1Is2The3Ultimate4PW5!'

    INTERN_BOT_CHANNEL_NAME: 'irc_channel'

