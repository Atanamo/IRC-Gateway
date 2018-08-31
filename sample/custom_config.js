
// Your config settings go here
//
module.exports = {

  SQL_HOST: '127.0.0.1',
  SQL_PORT: 3306,
  SQL_USER: 'your_username',
  SQL_PASSWORD: 'your_password',
  SQL_DATABASE_COMMON: 'chat_database',
  SQL_DATABASE_GAME: 'game_core',
  SQL_SOCKET_PATH: null,  // For windows

  SQL_TABLES: {
    GAMES_LIST: 'core_games',
    PLAYER_GAMES: 'core_users_2_games',
    GAME_PLAYER_IDENTITIES: 'core_user_identities'
  },

  WEB_SERVER_STATICS_DELIVERY_DIR: '<package_dir>/demo', // Use demo index.html file
  WEB_SERVER_CLIENT_DELIVERY_DIR: '<package_dir>/dist',  // Default

  SSL_CERT_PATH: '<package_dir>/sample/certs/server.crt',  // Use dummy ssl certificate
  SSL_KEY_PATH: '<package_dir>/sample/certs/server.key',   // Use dummy private key file

  MAX_BOTS: 0,  // Use mono-bot

};
