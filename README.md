"IRC Gateway" is a simple chat server based on Node.js and Socket.io with a sample web interface.

In general, it is meant to be used for browser-based multiplayer web games with various game instances/servers/worlds/maps.
The project was originally created for the browsergame "Stars, Gates & Realities" (http://sg-realities.de), also called SGR.

For each game world a player can create and join multiple chat channels (chat rooms).
Each channel saves all sent messages persintantly - at least a maximum number.
This allows groups of players to use own channels for time-displaced discussions.

The core feature of the server is the IRC bridge:
A channel can be mirrored to IRC via an IRC bot.
Players on ingame chat communicate to IRC through the bot.
Users directly connected to the corresponding IRC channel do only see the bot and its messages from players in the game.
But they can communicate with players on the ingame chat - the bot also mirrors the IRC communication to the ingame chat.

Therefor the chat server and its bot(s) are a kind of gateway between IRC and the in-game chat.


Contents
========

- [Components and features](#components-and-features)
- [Installation and setup](#installation-and-setup)
  - [Limitation notice](#limitation-notice)
- [Configuration](#configuration)
  - [Minimum config](#minimum-config)
  - [Example config](#example-config)
- [Demo page](#demo-page)
  - [Server config](#server-config)
  - [Alternative server config](#alternative-server-config)
  - [Open demo page](#open-demo-page)
- [Special channels](#special-channels)
  - [Global multi-game channel](#global-multi-game-channel)
  - [Public game channel](#public-game-channel)
- [Bot modes](#bot-modes)
  - [Mono bot](#mono-bot)
  - [Game-specific bot](#game-specific-bot)


Components and features
=======================

* Node server
  * Web server based on Express and Socket.io
  * Secure communication via HTTPS
  * IRC bot(s) for bidirectional mirroring
  * Replaceable database interface (MySQL used by default)
  * Simple logging mechanism

* Web client
  * Small javascript lib
  * Real-time chat via web sockets
  * Layout based on HTML tab pages
  * Server status tab
  * Managing of custom channels/tabs
  * Customizable design via CSS


Installation and setup
======================

* Install the package into your project:

  `$ npm install irc-gateway`

* Set up your database and data queries - see section "database"

* Set up your config file - see section "[Configuration](#configuration)"

* Set up the main file of your server application.

  See the sample server file for this: [\<package installation directory\>/sample/server.js](./sample/server.js)

  Applied to your application, the main file will look something like this:

  ```javascript
  const gateway = require('irc-gateway');

  const config = require('<your config file>');
  const datasource = require('<your datasource file>');

  const gatewayApp = gateway.setup(config, datasource);

  gatewayApp.start();

  // ...

  gatewayApp.stop();  // Stop the gateway (optional)
  ```

* Set up the html page for your chat client.

  See the demo page for this: [\<package installation directory\>/demo/index.html](./demo/index.html)


Limitation notice
-----------------

The `setup` function sets up the first instance created as singleton.

It's not possible to create multiple instances of a gateway within a single application, even if using different configurations or datasources.
Also, the configuration or datasource cannot be changed, once the instance is created.


Configuration
=============

The configuration is a simple JSON-like object containing key-value pairs.

Have a look on the default configuration, to see all possible settings and corresponding descriptions:

[\<package installation directory\>/src/server/config.default.coffee](./src/server/config.default.coffee)

Note that the file is written in CoffeeScript and therefor lacks the use of commas.

You can change any setting by defining and overwriting it in your own configuration.


Minimum config
--------------

Based on your `Datasource` and/or `DatabaseHandler` you have to define at least the settings of section "Database access config".

By default, they refer to the default `MysqlDatabaseHandler`. You may define completely different settings, if you use your own handler.


Example config
--------------

There is an example config file that is used for the demo server:

[\<package&nbsp;installation directory\>/sample/custom_config.js](./sample/custom_config.js)

The following shows a more practical config:

```javascript
{
  SQL_HOST: '127.0.0.1',
  SQL_PORT: 3306,
  SQL_USER: 'your_username',
  SQL_PASSWORD: 'your_password',
  SQL_DATABASE_COMMON: 'chat_database',
  SQL_DATABASE_GAME: 'game_core',
  SQL_SOCKET_PATH: '/var/run/mysqld/mysqld.sock'  // For debian

  SQL_TABLES: {
    GAMES_LIST: 'core_games',
    PLAYER_GAMES: 'core_users_2_games',
    GAME_PLAYER_IDENTITIES: 'core_user_identities'
  },

  WEB_SERVER_STATICS_DELIVERY_DIR: '/home/www/my_chat_gateway',
  WEB_SERVER_CLIENT_DELIVERY_DIR: '<package_dir>/dist',

  SSL_CERT_PATH: '/etc/letsencrypt/live/myawesomepage/cert.pem',
  SSL_KEY_PATH: '/etc/letsencrypt/live/myawesomepage/privkey.pem',

  IRC_SERVER_IP: 'portlane.se.quakenet.org',

  DEBUG_ENABLED: false,
  AUTH_ENABLED: true,
  CLIENT_AUTH_SECRET: 'super-secret-pepper',

  MAX_BOTS: 0,  // Use mono-bot
}
```

The example above delivers the static files (html page, images, css, etc.) from `'/home/www/my_chat_gateway'`. While the webclient script (`webclient.js`) is delivered from the package directory.

Note that the configuration of these webserver directories is completely optional.
You can also set them to null and use your own webserver instead.

In case you want to deliver the webclient script by your own webserver, simply copy the script from [\<package installation directory\>/dist/webclient.js](./dist/webclient.js) to the appropriate directory.


Demo page
=========

The project contains a very simple demo `index.html` as also an example stylesheet.
You can find it in the project's demo directory: [\<package installation directory\>/demo/](./demo/)

Before running anything, make sure you have set up the project by following the installation instructions.


Server config
-------------

Use following settings in the config:

```javascript
  WEB_SERVER_STATICS_DELIVERY_DIR: '<package_dir>/demo',  // Use demo index.html file
  WEB_SERVER_CLIENT_DELIVERY_DIR: '<package_dir>/dist',   // Default

  SSL_CERT_PATH: '<package_dir>/sample/certs/server.crt', // Dummy ssl certificate
  SSL_KEY_PATH: '<package_dir>/sample/certs/server.key',  // Dummy private key file
```

Then you have to start the chat server.


Alternative server config
-------------------------

Alternatively, you can use the sample server itself.
Just switch to the package installation directory and modify the database settings in the sample config:

[\<package installation directory\>/sample/custom_config.js](./sample/custom_config.js)

Then run the sample server:

* ``$ cd <package installation directory>``
* ``$ npm run demo``


Open demo page
--------------

When the server is running, you can open your browser and load the page on localhost. But note the server runs on HTTPS protocol.

Browse following address: ``https://localhost:8050``

(You have to use another port, if you overwrite the default port in the server's config file.)


Special channels
================

Global multi-game channel
--------------

The server sets up a special channel for all game worlds, which is mirrored to single public IRC channel.
This channel is called the "global channel" or "community channel".

The list of players currently connected to this channel is hidden to each other.
This allows players to join the channel secretly and only chat if they want.

A player can leave the channel temporarily, but is re-joined on every reconnect to the chat.


Public game channel
-------------------

For each game, the server also sets up a public game channel.
This channel is not mirrored to IRC, but also hides the list of joined players.

This allows players of a specific game to chat about things regarding only the context of their game and without a broadcast to public IRC.

A player can leave the channel temporarily, but is re-joined on every reconnect to the chat.


Bot modes
=========

The IRC bot can be set up in one of the following modes:
* Mono
* Game-specific


Mono bot
--------

For this mode, set configuration setting `MAX_BOTS` to 0 or less.

The mono-bot is a singleton bot.
He will represent players from all game worlds at once.
Because of this, messages from players in-game are prefixed or extended by the short name of their game world, when they are sent to IRC.

The bot does not represent a player on the ingame chat (In difference to game-specific mode).


Game-specific bot
-----------------

For this mode, set configuration setting `MAX_BOTS` to 1 or more.
Note that most IRC networks limit the number of simultaneous connections to the IRC.
Therefore, this mode is generally only useful for up to ca. 5 game worlds.

The game-specific bot is created per game world.
He will only represent players from its assigned game world.

Messages from players in-game are not prefixed or extended by a game name, when they are sent to IRC.
Instead, the name of the bot should define the game world, so messages from players have a clear origin.

Also, the bot does represent a player on the ingame chat, if the channel is mirrored to IRC.
By this, IRC channels are mirrored to ingame chat in exact same way as they occur on IRC.


