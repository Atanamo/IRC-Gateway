## CONFIG ##
##

# Overwrite config settings from the default config here.
# See "config.default.coffee" for detailed information of each setting.
module.exports = {

    # Datebase access config (MySQL)
    #

    SQL_HOST: '127.0.0.1'
    SQL_PORT: 3306

    SQL_USER: 'USERNAME'
    SQL_PASSWORD: 'SECRET'

    SQL_DATABASE_COMMON: 'irc_gateway'

    SQL_DATABASE_PREFIX_GAME: 'game_world_'

    SQL_SOCKET_PATH: '/var/run/mysqld/mysqld.sock'

    # Tables used by the database API implementation
    SQL_TABLES: {
        GAMES_LIST: 'game_worlds'
        PLAYER_GAMES: 'player_games'
        GAME_PLAYER_IDENTITIES: 'game_<id>_identities'
    }

}

