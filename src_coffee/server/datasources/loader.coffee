##
## Datasource loader ##
##
## For correct functioning, the files which use the datasource provided here
## must not be loaded before `setClass` is called.
## (Because of this, the index file uses lazy loading for the app entry file.)


datasourceClass = require('./ds.default')

module.exports = {

    setClass: (Clazz) ->
        datasourceClass = Clazz

    get: ->
        return datasourceClass
}

