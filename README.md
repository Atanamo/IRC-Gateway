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


Installation
============

* Download the project sources
* Set up the database on a MySQL server. Sadly, this is tricky and requires code modifications...
  * All database interaction is done in following file: `./src/server/database.coffee`
  * Have a look at the file and change the queries (and/or config) to match your environment:
  * Set up your database configuration by editing the file `./src/server/config.custom.coffee`
  * In the database file, you have to modify at least the method/queries
    containing `config.SQL_TABLES.GAMES_LIST` and the method `getClientIdentityData`.
  * All additional tables the chat system requires can be set up using the following file: `./setup_migration.sql`
* Navigate to the project directory (on shell), then run:
* `$ npm install`


Changing config
===============

* Overwrite the default settings:
  * Add/set your overwrite settings here: `./src/server/config.custom.coffee`
  * Look-up documentation of all settings here: `./src/server/config.default.coffee`
* Rebuild the JavaScript code (transcompile CoffeeScript code):
 	``$ cake build``
* Run server:
	``$ node ./dist/server/main.js``


Demo page
=========

The project contains a very simple `index.html` as demo page as also an example stylesheet.
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


