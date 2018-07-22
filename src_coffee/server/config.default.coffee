##
## CONFIG ##
##

module.exports = {

    # Datebase access config (MySQL)
    #

    # IP of the SQL server (mostly localhost)
    SQL_HOST: '127.0.0.1'

    # Port of the SQL server. Default is the MySQL port
    SQL_PORT: 3306

    # Username for connecting to SQL server
    SQL_USER: 'USERNAME'

    # Password for connecting to SQL server
    SQL_PASSWORD: 'SECRET'

    # The name of the database in which the app stores its own tables and/or core tables of the game
    SQL_DATABASE_COMMON: 'irc_gateway'

    # The name prefix of the database in which tables of a game world can be found
    # (To be appended with an id from common database - e.g. the game ID)
    SQL_DATABASE_PREFIX_GAME: 'game_world_'

    # The socket path of the SQL server. Default is the MySQL socket path.
    # (For MySQL, find out the path using 'mysqladmin variables | grep sock'.)
    # Define this path on Unix systems. Set the path to null on Windows systems.
    SQL_SOCKET_PATH: '/var/run/mysqld/mysqld.sock'

    # Tables used by the app (Only used by the database file, so you can set up your own entries too)
    SQL_TABLES: {
        # The name of the table in common db, which contains the list of game worlds
        GAMES_LIST: 'game_worlds'

        # The name of the table in common db, which maps a player to a game world (and an identity)
        PLAYER_GAMES: 'player_games'

        # The name of the table in game db, which contains the player identities of a related game
        # (Use <id> as a placeholder for the game ID)
        GAME_PLAYER_IDENTITIES: 'game_<id>_identities'

        # The name of the table for storing non-game/custom channels
        # (Must be created once, see database_setup.sql)
        CHANNEL_LIST: 'chat - channels'

        # The name of the table for storing user joins to custom channels
        # (Must be created once, see database_setup.sql)
        CHANNEL_JOININGS: 'chat - channeljoins'

        # The name of the table for storing chat histories of all channels
        # (Must be created once, see database_setup.sql)
        CHANNEL_LOGS: 'chat - channellogs'
    }


    # IRC access config
    #

    # IP of the IRC server to connect the gateway to
    IRC_SERVER_IP: 'underworld1.no.quakenet.org'

    # Port of the IRC server to connect the gateway to
    IRC_SERVER_PORT: 6667

    # The name of an IRC channel the global ingame channel should be mirrored to.
    # Ingame players of all games will have access to it.
    # Also see INTERN_GLOBAL_CHANNEL_TITLE.
    IRC_GLOBAL_CHANNEL: '#irc_gateway_test'

    # Prefix for an IRC channel name, which is used to mirror a custom channel to.
    # See INTERN_NONGAME_CHANNEL_PREFIX for more info.
    # Choose wisely to avoid conflicts with other channels on IRC.
    IRC_NONGAME_CHANNEL_PREFIX: '#igw_ingame_'


    # Webserver setup
    #

    # The port of the webserver started by this app
    WEB_SERVER_PORT: 8050

    # The ssl certificate to use for the https webserver
    SSL_CERT_PATH: './certs/server.crt'

    # The uncrypted private key file of the ssl certificate
    SSL_KEY_PATH: './certs/server.key'


    # Common settings
    #

    # Debug mode: Set to true, to enable any debug output
    DEBUG_ENABLED: true

    # Debug sub setting: Set to true, to enable debug output from irc communication by bots
    DEBUG_IRC_COMM: false

    # Channel security: Set to true, to force clients to set a password when creating a channel
    # (The password then must be at least 3 digits long)
    REQUIRE_CHANNEL_PW: false

    # Auth mode: Set to true, to enable client authentification by a security token
    # (Otherwise all valid player IDs will be accepted)
    AUTH_ENABLED: false

    # A secret string to be used as part of the security token, if AUTH_ENABLED is set
    # (The token needs to be sent from a client on login)
    CLIENT_AUTH_SECRET: 'SECRET_2'


    # General chat server settings
    #

    # Maximum number of simultaneously existing bots.
    # Use this, to obey connection limits to IRC server (Will also limit number of chats for game worlds).
    # Set it to 0 or less, to enable the mono-bot.
    # The mono-bot represents all game worlds at once and thus relays chats in a more general way.
    MAX_BOTS: 0

    # Maximum number of logs per channel in database.
    # This controls the max size of the chat logs table
    MAX_CHANNEL_LOGS: 100

    # Maximum number of channel logs for a client.
    # This controls the max length of a channel's chat history a client can request
    MAX_CHANNEL_LOGS_TO_CLIENT: 50

    # Maximum number of custom channels a client/user is allowed to create
    MAX_CHANNELS_PER_CLIENT: 3

    # Interval time in seconds, for looking up the games list in database and
    # create/destroy appropriate bots accordingly.
    # Set it to 0 or less to switch off the lookup - games list is only updated on app start then.
    GAMES_LOOKUP_INTERVAL: 5 * 60

    # Timeout in milliseconds, for waiting for reconnect of a client before broadcasting its disconnection
    # (If it reconnects before timeout, nothing is broadcasted)
    CLIENTS_DISCONNECT_DELAY: 2000


    # Internal chat server settings
    #

    # Display name of the global ingame channel (Also see INTERN_GLOBAL_CHANNEL_NAME).
    # <Use the setting in your database implementation>
    INTERN_GLOBAL_CHANNEL_TITLE: 'Community IRC'

    # Internal unique name for the global ingame channel.
    # This channel is mirrored to the IRC channel set by IRC_GLOBAL_CHANNEL.
    # <Use the setting in your database implementation>
    INTERN_GLOBAL_CHANNEL_NAME: 'community_channel'

    # Prefix for the internal name of ingame channels, which each represent one game (appended by the game ID).
    # These channels are so-called "game channels". They are created automatically.
    # They are pure ingame channels - which means, they are not mirrored to IRC.
    # <Use the setting in your database implementation>
    INTERN_GAME_CHANNEL_PREFIX: 'game_'

    # Prefix for the internal name of ingame channels, which can be created by players.
    # These channels are so-called "custom channels".
    # They are ingame channels in the first place, but can optionally be mirrored to IRC -
    # in that case the IRC_NONGAME_CHANNEL_PREFIX is used for the IRC channel name.
    # The prefix set here MUST differ from INTERN_GAME_CHANNEL_PREFIX.
    # <Use the setting in your database implementation>
    INTERN_NONGAME_CHANNEL_PREFIX: 'channel_'


    # Flooding protection
    #

    # Interval in milliseconds, to be used for flooding protection:
    # To recognize flooding, only client requests not older than this value are totaled up
    FLOODRATE_TIME_INTERVAL: 3 * 1000

    # Maximum total "weight" of client requests in time interval - A client is kicked, if he exceeds the limit
    FLOODRATE_LIMIT_WEIGHT: 33


    # Bot settings
    #

    # Delay time in milliseconds, for reconnecting to server, when connection has been refused
    BOT_RECONNECT_DELAY: 61 * 1000

    # The "official" name of the bot as displayed in its version info, may also use this in further name patterns
    BOT_NAME: 'GameCommBot'

    # The nick name of the Bot on IRC.
    # If not using the mono-bot: Use <id> as a placeholder for the game ID
    BOT_NICK_PATTERN: 'Game<id>'

    # The user name of the Bot on IRC.
    # If not using the mono-bot: Use <id> as a placeholder for the game ID
    BOT_USERNAME_PATTERN: 'GameCommBot_<id>'

    # The real name of the Bot on IRC.
    # If not using the mono-bot: Use <id> and <name> as a placeholders for the game ID and game name
    BOT_REALNAME_PATTERN: '<name> - GameCommBot <id>'

    # A lower-case label used by the bot to commonly name its game world
    # (For example 'game-instance', 'map', 'galaxy', etc.).
    # Used for some bot commands.
    BOT_GAME_LABEL: 'game-world'

    # Bot message on channel part in IRC (which should only occur on its termination)
    BOT_LEAVE_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'

    # Bot message on server quit in IRC (which should only occur on its termination)
    BOT_QUIT_MESSAGE: 'Oh, cruel world... My time has come to leave, goodbye!'

}
