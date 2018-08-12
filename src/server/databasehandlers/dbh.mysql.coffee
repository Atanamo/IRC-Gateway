
## Include libraries
Q = require 'q'
mysql = require 'mysql'

## Include app logger
appLogger = require '../logger'

## Include abstract handler
AbstractDatabaseHandler = require './dbh.abstract'


## Handler for interacting with MySQL databases
##
class MysqlDatabaseHandler extends AbstractDatabaseHandler
    log: null
    config: null
    connection: null

    constructor: (dbConfig, logger=appLogger) ->
        @config = dbConfig
        @log = logger

    connect: ->
        deferred = Q.defer()

        ## Open connection to database
        @connection = mysql.createConnection
            host: @config.SQL_HOST
            port: @config.SQL_PORT
            user: @config.SQL_USER
            password: @config.SQL_PASSWORD
            database: @config.SQL_DATABASE_COMMON
            charset: @config.SQL_CONNECTION_CHARSET or 'UTF8MB4_GENERAL_CI'
            socketPath: @config.SQL_SOCKET_PATH

        @connection.connect (err) =>
            if err
                @log.error(err, 'Database connection')
                deferred.reject(err)
            else
                @log.debug 'Established database connection'
                deferred.resolve()

        return deferred.promise

    disconnect: ->
        deferred = Q.defer()

        if @connection.state is 'disconnected'
            @connection.destroy()
        else
            @connection.end (err) =>
                if err
                    @log.error(err, 'Database disconnect')
                else
                    @log.debug 'Closed database connection'
                @connection.destroy()
                deferred.resolve()

        return deferred.promise

    #
    # Database query helper routines
    #

    toQuery: (wildValue) ->
        return mysql.escape(wildValue)

    sendQuery: (sqlQuery) ->
        deferred = Q.defer()

        @connection.query sqlQuery, (err, resultData, fieldsMetaData) =>
            if err
                @log.error(err, 'Database query')
                deferred.reject(err)
            else
                deferred.resolve(resultData)

        return deferred.promise

    doTransaction: (transactionRoutineFunc) ->
        deferred = Q.defer()

        @connection.beginTransaction (err) =>
            if err
                @log.error(err, 'Database transaction')
                deferred.reject(err)
            else
                routinePromise = transactionRoutineFunc()
                deferred.resolve(routinePromise)

        promise = deferred.promise
        promise = promise.then =>
            innerDeferred = Q.defer()
            @connection.commit (err) =>
                if err
                    @log.error(err, 'Database transaction commit')
                    innerDeferred.reject(err)
                else
                    innerDeferred.resolve()
            return innerDeferred.promise
        promise.fail =>
            @connection.rollback()

        return promise

    readSimpleData: (sqlQuery, rejectIfEmpty=false) ->
        promise = @sendQuery(sqlQuery)
        promise = promise.then (resultRows) =>
            resultData = resultRows[0]
            if rejectIfEmpty and not resultData?
                err = new Error('Result is empty')
                err.isDatabaseResult = true
                throw err
            return resultData
        return promise

    readMultipleData: (sqlQuery) ->
        return @sendQuery(sqlQuery)



## Export class
module.exports = MysqlDatabaseHandler

