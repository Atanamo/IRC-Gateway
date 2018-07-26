
// Your config settings go here
//
module.exports = {

  SQL_HOST: '127.0.0.1',
  SQL_PORT: 3306,
  SQL_USER: 'your_username',
  SQL_PASSWORD: 'your_password',
  SQL_DATABASE_COMMON: 'some_core_database',
  SQL_DATABASE_PREFIX_GAME: 'some_game_database_',
  SQL_SOCKET_PATH: null,  // For windows

  SQL_TABLES: {
    GAMES_LIST: 'core_games',
    PLAYER_GAMES: 'core_users_2_games',
    GAME_PLAYER_IDENTITIES: 'game_<id>_players'
  },

  MAX_BOTS: 0,  // Use mono-bot

};
