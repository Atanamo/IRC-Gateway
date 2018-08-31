
## Include libraries
Q = require 'q'


## Interface of handlers interacting with databases
##
class AbstractDatabaseHandler

    constructor: (config, logger) ->
        return

    connect: ->
        return Q.defer().promise

    disconnect: ->
        return Q.defer().promise


    #
    # Query helper routines
    #

    toQuery: (wildValue) ->
        return ''

    sendQuery: (sqlQuery) ->
        return Q.defer().promise

    doTransaction: (transactionRoutineFunc) ->
        return Q.defer().promise

    readSimpleData: (sqlQuery, rejectIfEmpty=false) ->
        return Q.defer().promise

    readMultipleData: (sqlQuery) ->
        return Q.defer().promise



## Export class
module.exports = AbstractDatabaseHandler

