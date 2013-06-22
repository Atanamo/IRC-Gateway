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


* Note, that for developing purposes game worlds might be called "galaxies" inside the project, due to the terminology of SGR.
