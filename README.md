IRC Gateway
===========

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



Table of contents
========

- [Components and features](#components-and-features)
- [Installation and setup](#installation-and-setup)
  - [Limitation notice](#limitation-notice)
- [Data queries](#data-queries)
  - [Datasource class](#datasource-class)
  - [Database handler class](#database-handler-class)
  - [Example datasource and database handler](#example-datasource-and-database-handler)
  - [Default database scheme](#default-database-scheme)
- [Configuration](#configuration)
  - [Minimum config](#minimum-config)
  - [Example config](#example-config)
- [Webclient API](#webclient-api)
  - [Client initialization](#client-initialization)
  - [Client methods](#client-methods)
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
  * Chat history managing
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

* Set up your database and data queries - see section "[Data queries](#data-queries)"

* Set up your config file - see section "[Configuration](#configuration)"

* Set up the main file of your server application.

  See the sample server file for this: [\<gateway\>/sample/server.js](./sample/server.js)

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

  See the demo page for this: [\<gateway\>/demo/index.html](./demo/index.html)

  The following is the basic set-up:

  ```html
  <script type="text/javascript" src="/chat/webclient.js"></script>

  <script type="text/javascript">
      const authData = {
          userID: 42,
          gameID: 123
      };

      document.addEventListener('DOMContentLoaded', function() {
          const chat = new GatewayChat('https://localhost', 8050, authData);
          chat.start();
      });
  </script>
  ```

  For options see section "[Webclient API](#webclient-api)".


Limitation notice
-----------------

The `setup` function sets up the first instance created as singleton.

It's not possible to create multiple instances of a gateway within a single application, even if using different configurations or datasources.
Also, the configuration or datasource cannot be changed, once the instance is created.



Data queries
============

The gateway handles all data queries and data managing by using a so-called "Datasource".
It is a singleton proxy to access a database on several points in the application.

A datasource consists of the following elements:

* The methods to read/write data
* A database handler object

To create an instance of the irc-gateway, you need to provide a datasource class for it.
It has to be passed to the gateway's `setup` routine.


Datasource class
----------------

The `Datasource` class must be derived from class `AbstractDatasource`.

* For detail documentation of all methods required, see: [\<gateway\>/src/server/datasources/ds.abstract.coffee](./src/server/datasources/ds.abstract.coffee)
* For the default implementation of the abstract class, see the `DefaultDatasource`: [\<gateway\>/src/server/datasources/ds.default.coffee](./src/server/datasources/ds.default.coffee)

You can import these classes from the gateway package as follows:
```javascript
const gateway = require('irc-gateway');

// The abstract class - only required for very custom implementations
const AbstractDatasource = gateway.AbstractDatasource;

// The default class - use this to override
const DefaultDatasource = gateway.DefaultDatasource;
```

In almost all cases it is sufficient to use the `DefaultDatasource` as a basis and override only the methods specific to your game.

If you do so, you usually only have to overwrite the methods located in the following sections of the `DefaultDatasource`:

* Client identity
* Game-specific queries

The `DefaultDatasource` only contains example implementations for these methods.
It's very unlikely they will match your game's specific database.

**Note:**<br/>
The `DefaultDatasource` expects a database scheme as defined by the package's migration script.
If you modify the tables, you also need to overwrite the corresponding methods of the datasource.
See [Default database scheme](#default-database-scheme) for details.


Database handler class
----------------------

The database handler is used to abstract a concrete database system like MySQL, PostgreSQL, MongoDB, etc.

The `DefaultDatasource` uses the `MysqlDatabaseHandler` by default to acess a MySQL database.

You can create your own database handler by inheriting from `AbstractDatabaseHandler` or an existing implementation of it.

* For the methods to implement, see `AbstractDatabaseHandler`: [\<gateway\>/src/server/databasehandlers/dbh.abstract.coffee](./src/server/databasehandlers/dbh.abstract.coffee)
* For a concrete implementation, see the `MysqlDatabaseHandler`: [\<gateway\>/src/server/databasehandlers/dbh.mysql.coffee](./src/server/databasehandlers/dbh.mysql.coffee)

You can import these classes from the gateway package as follows:
```javascript
const gateway = require('irc-gateway');

// The abstract class - use this to implement a new database system
const AbstractDatabaseHandler = gateway.AbstractDatabaseHandler;

// The MySQL class - use this for small customizations with MySQL database
const MysqlDatabaseHandler = gateway.MysqlDatabaseHandler;
```

Of course, depending on the database you use, the `Datasource` methods must be modified to comply with concrete SQL dialects or the query API.
For example, NoSQL systems require a completely different kind of queries, lacking the use of SQL at all...


Example datasource and database handler
---------------------------------------

The following example shows the principle to use the datasource and database handler classes.
(Note that the shown customizations are pretty useless, they are for demonstration purposes only.)

```javascript
const gateway = require('irc-gateway');

const MysqlDatabaseHandler = gateway.MysqlDatabaseHandler;
const DefaultDatasource = gateway.DefaultDatasource;

// Custom database handler
class VerboseMysqlDatabaseHandler extends MysqlDatabaseHandler {

    // Extend the sending of any query with a logging mechanism
    sendQuery(sqlQuery) {
        @log.debug('SQL:', sqlQuery);
        return super(sqlQuery);
    }
}

// Custom datasource
class MyCustomDatasource extends DefaultDatasource {

    // Use the custom handler
    _createHandler(config) {
        return new VerboseMysqlDatabaseHandler(config);
    }

    // Overwrite the default shortening routine
    _getShortenedGameTitle(fullGameTitle) {
        return String(fullGameTitle).replace('world', 'w.');
    }
}
```


Default database scheme
-----------------------

The package provides a simple SQL migration script, which sets up the tables required for the chat system itself:

[\<gateway\>/setup_migration.sql](./setup_migration.sql)

It provides the following essential tables (named by the corresponding config setting):

* Channel list: &nbsp; "`chat - channels`"
* Channel joinings: &nbsp; "`chat - channeljoins`"
* Channel logs: &nbsp; "`chat - channellogs`"

Just switch over to your database system and import/execute the script.

The script is designed for a MySQL database and matches the methods of the `DefaultDatasource`.
You may modify it for your own requirements. Just don't forget to modify the datasource class, too.

If you rename the tables, you only need to change the corresponding config settings (See `SQL_TABLES`).



Configuration
=============

The configuration is a simple JSON-like object containing key-value pairs.

Have a look on the default configuration, to see all possible settings and corresponding descriptions:

[\<gateway\>/src/server/config.default.coffee](./src/server/config.default.coffee)

Note that the file is written in CoffeeScript and therefor lacks the use of commas.

You can change any setting by defining and overwriting it in your own configuration.


Minimum config
--------------

Based on your `Datasource` and/or `DatabaseHandler` you have to define at least the settings of section "Database access config".

By default, they refer to the default `MysqlDatabaseHandler`. You may define completely different settings, if you use your own handler.


Example config
--------------

There is an example config file that is used for the demo server:

[\<gateway\>/sample/custom_config.js](./sample/custom_config.js)

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

In case you want to deliver the webclient script by your own webserver, simply copy the script from [\<gateway\>/dist/webclient.js](./dist/webclient.js) to the appropriate directory.



Webclient API
=============

The most easy way to include the webclient is via a script tag in your web page:
```html
<script type="text/javascript" src="/chat/webclient.js"></script>
```
It will provide the global class `GatewayChat` via the `window` object.

Alternatively, the client supports to be bundled by Browserify or Webpack as common-js module.
```javascript
const GatewayChat = require('node_modules/irc-gateway/dist/webclient.js');
```


Client initialization
---------------------

The client is fully represented by the `GatewayChat` class.
It allows following arguments on instantiation (in specified order):

* `serverIP [string]`:
  The URL of the irc-gateway server, without port.

* `serverPort [int]`:
  The port the irc-gateway server runs on. Set in the server config.

* `authData [object]`:
  An object containing the authentication data for the client and user.
  It expects following properties:

  * `userID`: The id of the player's account or game identity/character.
  * `gameID`: The id of the player's game world.
  * `token`: [Optional] The server's security token, if enabled. See `AUTH_ENABLED` and `CLIENT_AUTH_SECRET` in server config and `getClientIdentityData` of the `Datasource`.

* `options [object]`:
  An optional object containing settings for the webclient UI.
  Following properties can be passed as settings:

  * `parentElement [string|Node]`:
    Selector string or DOM node of the element the webclient should be appended to.
    The selector string supports jQuery syntax. Defaults to body tag.
  * `signalizeMessagesToWindow [bool]`:
    Flag to signalize unread messages on the web page.
    If enabled, new messages will cause the page's title to be prepended with the number of unread messages.
    The title may also "blink" with certain notification on some chat events.
  * `tabClickCallback [function]`:
    A function to be called each time a tab of the chat UI was clicked/selected.
    The selected tab page is passed to the callback as a DOM node.


Client methods
--------------

* **`start(): void`**

    Establishes the web socket connection to the server, tries to authenticate the client on server
    and starts up the chat.

* **`setTabContentVisibilityInfo(isVisible): void`**

    Sets a boolean flag to inform the webclient whether or not its content is currently visible because of environment constraints.
    This flag forces to show or reset markers for unread messages on the tabs of the chat client, independently of the focus of the web page and the selected tab.
    The method can be useful if the webclient UI is forced to a minimum height, for example.



Demo page
=========

The project contains a very simple demo `index.html` as also an example stylesheet.
You can find it in the project's demo directory: [\<gateway\>/demo/](./demo/)

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

[\<gateway\>/sample/custom_config.js](./sample/custom_config.js)

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


