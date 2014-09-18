
## Include app modules
Config = require './config'


# TODO: Teils nur Methodenruempfe da.
## Class definition - Database:
## Wraps the database of choice.
## Provides ready-to-use methods for all needed read/write operations
class Database

    connect: () ->
        ## Open connection to database
        # TODO
        #...
        #log.info 'Database started'

    getClientChannels: (client) ->
        # TODO
        # db.select("Select channel from channels, client_channels where client = '#{clientIdent}'")

        tempdata = [
                name: 'galaxy_test'
            ,
                name: 'galaxy_test_group01'
        ]

        return tempdata

    getChannelData: (channelIdent) ->
        tempdata = {
            'galaxy_test':
                title: 'Test-Galaxie'
                is_public: true
            'galaxy_test_group01':
                title: 'Ally 1'
                is_public: false
        }

        tempdata[Config.INTERN_BOT_CHANNEL_NAME] =
            title: 'SGR Support'
            is_public: true

        return tempdata[channelIdent]

    addClientToChannel: (client, channelIdent) ->
        # TODO

    removeClientFromChannel: (client, channelIdent) ->
        # TODO

    saveSingleValue: (namespace, key, value) ->
        # TODO
        # db.table("values").update(namespace + '_' + key, value)




## Export class
module.exports = Database

