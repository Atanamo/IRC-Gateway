"IRC Gateway" is a simple chat server based on Node.js and Socket.io with an example web UI.

In general it is meant to be used for browser-based multiplayer web games with various game instances/servers/worlds/maps.
But in specific, the project targets the german browsergame "Stars, Gates & Realities" (http://sg-realities.de), also called SGR.*

For each game world a player can create and join multiple chat channels (chat rooms).
Each channel saves all sent messages persintantly - at least a maximum number.
By this, a player can read the channel history after joining. This allows groups of players to use own channels for time-displaced discussions in kind of a forum.

Additionally there is a special channel for each world, which is the in-game representation of a public IRC channel.
The list of players currently connected to this channel is hidden to each other. The players only communicate through an IRC bot.

Clients directly connected to the IRC channel do only see the bot and what he messages in role of a player in-game.
This way, on IRC there is only one bot for each game world. The bot represents all players in its world.
(Therefor the chat server and its bots are a kind of gateway between IRC and in-game chat.)


(*) Note, that for developing purposes game worlds might be called "galaxies" inside the project, due to the terminology of SGR.



Installation
============

* Download the project sources
* Set up the database on a MySQL server. Sadly, this is tricky and requires code modifications...
  * All database interaction is done in following file: ./src_coffee/server/database.coffee
  * Have a look at the file and change the queries (and/or config) to match your environment:
  * You have to modify all queries containing `Config.SQL_TABLES.GAMES_LIST` and the method `getClientIdentityData`.
  * All additional tables the chat system requires can be set up using the following file: ./setup_migration.sql
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

> https://localhost:8050


Changing config
===============

* Edit the server settings in: `./src_coffee/server/config.coffee`
* Rebuild the JavaScript code (transcompile CoffeeScript code): 
 	``$ cake build``
* Run server:
	``$ node ./src_js/server/main.js``



