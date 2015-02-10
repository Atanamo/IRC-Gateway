
## CONFIG ##

# Bot sub config
botNickPrefix = '_Galaxy'       # Prefix for bot's nick name on IRC
botName = 'SGR GalaxyBot'       # Bot's official name
botVersion = 'v1.1'             # Bot's version number string
botLastUpdate = '2014-12-28'    # Update info for bot version

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

    DEBUG_ENABLED: true    # Set to true, to enable some debug output
    DEBUG_IRC_COMM: false  # Set to true, to enable debug output from irc communication by bots
    AUTH_ENABLED: false    # Set to true, to enable client authentification by a security token (Otherwise all valid player IDs will be accepted)
    REQUIRE_CHANNEL_PW: false  # Set to true, to force clients to set a password when creating a channel (The password then must be at least 3 digits long)

    WEB_SERVER_PORT: 8050  # The port of the webserver started by this app

    CLIENT_AUTH_SECRET: 'SECRET_2'  # A secret string to be used as part of the security token (The token needs to be sent from a client on login)

    GAMES_LOOKUP_INTERVAL: 20       # Interval time in seconds, for looking up the games list in database and create/destroy appropriate bots accordingly
    MAX_CHANNEL_LOGS: 100           # Maximum number of logs per channel in database - This controls the max size of the chat logs table
    MAX_CHANNEL_LOGS_TO_CLIENT: 50  # Maximum number of channel logs for a client - This controls the max length of a channel's chat history a client can request
    MAX_CHANNELS_PER_CLIENT: 5      # Maximum number of channels a client/user is allowed to create
    MAX_BOTS: 5                     # Maximum number of simultaneously existing bots - Use this, to obey connection limits to IRC server (Will also limit number of chats for game worlds)

    BOT_RECONNECT_DELAY: 61000      # Delay time in milliseconds, for reconnecting to server, when connection has been refused
    BOT_NICK_PATTERN: "#{botNickPrefix}<id>"                  # The nick name of the Bot on IRC, with <id> as a placeholder for the game ID
    BOT_USERNAME_PATTERN: "Galaxy<id>Bot"                     # The user name of the Bot on IRC, with <id> as a placeholder for the game ID
    BOT_REALNAME_PATTERN: "<name> - #{botName} <id>"          # The real name of the Bot on IRC, with <id> and <name> as placeholders for the game ID and name
    BOT_VERSION_STRING: "#{botName}, #{botVersion} " +        # The version string of the Bot, for requests on IRC
                        "(Last update: #{botLastUpdate}) " +
                        "-- Created 2014 by Atanamo"

    BOT_LEAVE_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'  # Bot message on channel part
    BOT_QUIT_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'   # Bot message on server quit

    IRC_SERVER_IP: ircServerIP
    IRC_SERVER_PORT: ircServerPort

    IRC_GLOBAL_CHANNEL: ircGlobalChannel
    IRC_NONGAME_CHANNEL_PREFIX: '#sgr_ingame_channel_'
    #IRC_LOCAL_CHANNEL_PASSWORD: '!This1Is2The3Ultimate4PW5!'

    INTERN_GLOBAL_CHANNEL_TITLE: "IRC (#{ircGlobalChannel})"
    INTERN_GLOBAL_CHANNEL_NAME: 'irc_channel'
    INTERN_GAME_CHANNEL_PREFIX: 'galaxy_'
    INTERN_NONGAME_CHANNEL_PREFIX: 'channel_'  # Must differ from INTERN_GAME_CHANNEL_PREFIX

    SQL_HOST: mysqlServerIP
    SQL_PORT: mysqlServerPort
    SQL_USER: mysqlUser
    SQL_PASSWORD: mysqlPassword
    SQL_DATABASE_COMMON: mysqlCommonDatabase
    SQL_DATABASE_PREFIX_GAME: mysqlGameDatabasePrefix
    SQL_SOCKET_PATH: '/var/run/mysqld/mysqld.sock'  # Define this path on unix systems. Find out the path using 'mysqladmin variables | grep sock'

    SQL_TABLES:
        GAMES_LIST: 'game_worlds'         # The name of the table in common db, which contains the list of game worlds
        PREFIX_GAME_TABLE: 'game_'        # The name prefix of tables in game db, which contain data of a game world's contents
        POSTFIX_GAME_PLAYERS: '_players'  # The name postfix of the game table, which contains the list of a game world's players
        CHANNEL_LIST: 'chat - channels'
        CHANNEL_JOININGS: 'chat - channeljoins'
        CHANNEL_LOGS: 'chat - channellogs'
