##
## CONFIG ##
##

# MySQL access config
mysqlServerIP = '127.0.0.1'
mysqlServerPort = 3306
mysqlUser = 'USERNAME'
mysqlPassword = 'SECRET'
mysqlCommonDatabase = 'irc_gateway'      # The name of the database in which the app stores its own tables and/or core tables of the game
mysqlGameDatabasePrefix = 'game_world_'  # The name prefix of the database in which tables of a game world can be found (To be appended with a database id)

# IRC access config
ircServerIP = 'underworld1.no.quakenet.org'
ircServerPort = 6667
ircGlobalChannel = '#irc_gateway_test'

# Bot sub config
botNickPrefix = '_Game'       # Prefix for bot's nick name on IRC
botName = 'GameCommBot'       # Bot's official name
botVersion = 'v2.0'           # Bot's version number string
botLastUpdate = '2018-07-15'  # Update info for bot version


## Main config
module.exports =

    DEBUG_ENABLED: true    # Set to true, to enable some debug output
    DEBUG_IRC_COMM: false  # Set to true, to enable debug output from irc communication by bots
    AUTH_ENABLED: false    # Set to true, to enable client authentification by a security token (Otherwise all valid player IDs will be accepted)
    REQUIRE_CHANNEL_PW: false  # Set to true, to force clients to set a password when creating a channel (The password then must be at least 3 digits long)

    WEB_SERVER_PORT: 8050  # The port of the webserver started by this app
    SSL_CERT_PATH: './certs/server.crt'  # The ssl certificate to use for the https webserver
    SSL_KEY_PATH: './certs/server.key'   # The uncrypted private key file of the ssl certificate

    CLIENT_AUTH_SECRET: 'SECRET_2'  # A secret string to be used as part of the security token (The token needs to be sent from a client on login)

    GAMES_LOOKUP_INTERVAL: 60       # Interval time in seconds, for looking up the games list in database and create/destroy appropriate bots accordingly
    CLIENTS_DISCONNECT_DELAY: 2000  # Timeout in milliseconds, for waiting for reconnect of a client before broadcasting its disconnection (If it reconnects before timeout, nothing is broadcasted)
    MAX_CHANNEL_LOGS: 100           # Maximum number of logs per channel in database - This controls the max size of the chat logs table
    MAX_CHANNEL_LOGS_TO_CLIENT: 50  # Maximum number of channel logs for a client - This controls the max length of a channel's chat history a client can request
    MAX_CHANNELS_PER_CLIENT: 3      # Maximum number of channels a client/user is allowed to create
    MAX_BOTS: 0                     # Maximum number of simultaneously existing bots - Use this, to obey connection limits to IRC server (Will also limit number of chats for game worlds).
                                    # Set it to 0 or less, to enable the mono-bot - The mono-bot represents all game worlds at once and thus relays chats in a more general way.

    FLOODRATE_TIME_INTERVAL: 3000   # Interval in milliseconds, to be used for flooding protection: To recognize flooding, only client requests not older than this value are totaled up
    FLOODRATE_LIMIT_WEIGHT: 33      # Maximum total "weight" of client requests in time interval - A client is kicked, if he exceeds the limit

    BOT_RECONNECT_DELAY: 61000      # Delay time in milliseconds, for reconnecting to server, when connection has been refused
    BOT_NICK_PATTERN: "#{botNickPrefix}<id>"                  # The nick name of the Bot on IRC, with <id> as a placeholder for the game ID (if not using mono-bot)
    BOT_USERNAME_PATTERN: "#{botName}_<id>"                   # The user name of the Bot on IRC, with <id> as a placeholder for the game ID (if not using mono-bot)
    BOT_REALNAME_PATTERN: "<name> - #{botName} <id>"          # The real name of the Bot on IRC, with <id> and <name> as placeholders for the game ID and name (if not using mono-bot)
    BOT_VERSION_STRING: "#{botName}, #{botVersion} " +        # The version string of the Bot, for requests on IRC
                        "(Last update: #{botLastUpdate}) " +
                        "-- Created 2014 by Atanamo"

    BOT_LEAVE_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'  # Bot message on channel part
    BOT_QUIT_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'   # Bot message on server quit

    IRC_SERVER_IP: ircServerIP
    IRC_SERVER_PORT: ircServerPort
    IRC_GLOBAL_CHANNEL: ircGlobalChannel
    IRC_NONGAME_CHANNEL_PREFIX: '#igw_ingame_'

    INTERN_GLOBAL_CHANNEL_TITLE: 'Community IRC'
    INTERN_GLOBAL_CHANNEL_NAME: 'community_channel'
    INTERN_GAME_CHANNEL_PREFIX: 'game_'
    INTERN_NONGAME_CHANNEL_PREFIX: 'channel_'  # Must differ from INTERN_GAME_CHANNEL_PREFIX

    SQL_HOST: mysqlServerIP
    SQL_PORT: mysqlServerPort
    SQL_USER: mysqlUser
    SQL_PASSWORD: mysqlPassword
    SQL_DATABASE_COMMON: mysqlCommonDatabase
    SQL_DATABASE_PREFIX_GAME: mysqlGameDatabasePrefix
    SQL_SOCKET_PATH: '/var/run/mysqld/mysqld.sock'  # Define this path on unix systems. Find out the path using 'mysqladmin variables | grep sock'

    SQL_TABLES:
        GAMES_LIST: 'game_worlds'                # The name of the table in common db, which contains the list of game worlds
        PLAYER_GAMES: 'player_games'             # The name of the table in common db, which maps a player to a game world (and an identity)
        GAME_PLAYER_IDENTITIES: 'game_<id>_identities'  # The name of the table in game db, which contains the player identities of a related game (With <id> as a placeholder for the game ID)

        CHANNEL_LIST: 'chat - channels'          # The name of the table for storing non-game/custom channels (Must be created, see database_setup.sql)
        CHANNEL_JOININGS: 'chat - channeljoins'  # The name of the table for storing user joins to custom channels (Must be created, see database_setup.sql)
        CHANNEL_LOGS: 'chat - channellogs'       # The name of the table for storing chat histories of all channels (Must be created, see database_setup.sql)

