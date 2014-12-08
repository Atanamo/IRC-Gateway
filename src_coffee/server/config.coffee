
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

# MySQL sub config
mysqlServerIP = '127.0.0.1'
mysqlServerPort = 3306
mysqlUser = 'sgr'
mysqlPassword = 'SECRET'
mysqlCommonDatabase = 'irc_gateway'      # The name of the database in which the app stores its own tables and/or core tables of the game
mysqlGameDatabasePrefix = 'game_world_'  # The name prefix of the database in which tables of a game world can be found (To be appended with a database id)


# Main config
module.exports =

    DEBUG_ENABLED: true   # Set to true, to enable some debug output
    DEBUG_IRC_COMM: false  # Set to true, to enable debug output from irc communication by bots

    WEB_SERVER_PORT: 8050  # The port of the webserver started by this app

    CLIENT_AUTH_SECRET: 'g4t3w4y'  # A secret string to be used as part of the security token (The token needs be sent from a client on login)

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

    SQL_HOST: mysqlServerIP
    SQL_PORT: mysqlServerPort
    SQL_USER: mysqlUser
    SQL_PASSWORD: mysqlPassword
    SQL_DATABASE_COMMON: mysqlCommonDatabase
    SQL_DATABASE_PREFIX_GAME: mysqlGameDatabasePrefix

    SQL_TABLES:
        GAMES_LIST: 'game_worlds'         # The name of the table in common db, which contains the list of game worlds
        PREFIX_GAME_TABLE: 'game_'        # The name prefix of tables in game db, which contain data of a game world's contents
        POSTFIX_GAME_PLAYERS: '_players'  # The name postfix of the game table, which contains the list of a game world's players


