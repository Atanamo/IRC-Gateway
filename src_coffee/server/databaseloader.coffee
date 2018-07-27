##
## Database loader ##
##
## For correct functioning, the files which use the database provided here
## must not be loaded before `setClass` is called.
## (Because of this, the index file uses lazy loading for the app entry file.)


databaseClass = require('./database.default')

module.exports = {

    setClass: (Clazz) ->
        databaseClass = Clazz

    get: ->
        return databaseClass
}

