"IRC Gateway" is a simple chat server based on Node.js and Socket.io with an example web UI.

In general it is meant to be used for browser-based multiplayer web games with various game instances/servers/worlds/maps.
But in specific, the project targets the german browsergame "Stars, Gates & Realities" (http://sg-realities.de), also called SGR.*

For each game world a player can create and join multiple chat channels (chat rooms).
Each channel saves all sent messages persintantly - at least a maximum number.
By this, a player can read the channel history after joining. This allows groups of players to use own channels for time-displaced discussions in kind of a forum.

But the core feature of the server is the IRC bridge:
A channel can be mirrored to IRC by using an IRC bot.
Players on ingame chat communicate through the bot to IRC.
Users directly connected to the corresponding IRC channel do only see the bot and what he messages in role of a player in-game.
And of course they can communicate with players in-game - the bot will also mirror IRC communication to the ingame chat.

Therefor the chat server and its bot(s) are a kind of gateway between IRC and the in-game chat.


(*) Note, that for developing purposes game worlds might be called "galaxies" inside the project, due to the terminology of SGR.



Installation
============

* Download the project sources
* Set up the database on a MySQL server. Sadly, this is tricky and requires code modifications...
  * All database interaction is done in following file: `./src_coffee/server/database.coffee`
  * Have a look at the file and change the queries (and/or config) to match your environment:
  * Set up your database configuration by editing the file `./src_coffee/server/config.custom.coffee`
  * In the database file, you have to modify at least the method/queries
    containing `Config.SQL_TABLES.GAMES_LIST` and the method `getClientIdentityData`.
  * All additional tables the chat system requires can be set up using the following file: `./setup_migration.sql`
* Navigate to the project directory (on shell), then run:
* `$ npm install`


Demo page
=========

The project contains a very simple `index.html` as demo page.

Before running anything, make sure you have set up the project following the installation instructions.
Then you have to start the chat server (including a web server):

  ``$ node ./src_js/server/main.js``

Afterwards, you can open your browser and load the page on localhost. But note the server runs on SSL protocol.
So based on the default settings in the server's config file, you have to browse following address:

  ``https://localhost:8050``


Changing config
===============

* Overwrite the default settings:
  * Add/set your overwrite settings here: `./src_coffee/server/config.custom.coffee`
  * Look-up documentation of all settings here: `./src_coffee/server/config.default.coffee`
* Rebuild the JavaScript code (transcompile CoffeeScript code):
 	``$ cake build``
* Run server:
	``$ node ./src_js/server/main.js``


Special channels
================

Global multi-game channel
--------------

The server sets up a special channel for all game worlds, which is mirrored to single public IRC channel.
This channel is called the "global channel" or "community channel".

The list of players currently connected to this channel is hidden to each other.
This allows players to join the channel secretly and only chat if they want.

A player can leave the channel temporary, but is re-joined on every reconnect to the chat.


Public game channel
-------------------

For each game, the server also sets up a public game channel.
This channel is not mirrored to IRC, but also hides the list of joined players.

This allows players of a specific game to chat about things regarding only the context of their game and without a broadcast to public IRC.

A player can leave the channel temporary, but is re-joined on every reconnect to the chat.


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
Note that there are limits for connections to IRC - mostly this mode is only practical for up to ca. 5 game worlds.

The game-specific bot is created per game world.
He will only represent players from its assigned game world.

Messages from players in-game are not prefixed or extended by a game name, when they are sent to IRC.
Instead, the name of the bot should define the game world, so messages from players have a clear origin.

Also, the bot does represent a player on the ingame chat, if the channel is mirrored to IRC.
By this, IRC channels are mirrored to ingame chat in exact same way as they occur on IRC.

