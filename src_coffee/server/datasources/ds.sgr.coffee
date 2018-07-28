
## Include app modules
config = require '../config'

## Include data classes
DefaultDatasource = require './ds.default'


## Abstraction of data managing methods for the browsergame SG-Realities.
## See `DefaultDatasource` for more.
##
## Structure:
## * Client identity
## * Game-specific queries
##
class SgrDatasource extends DefaultDatasource

    #
    # Client identity
    #

    # Returns the saved folk-related identification data for the given user in the given galaxy.
    # @override
    getClientIdentityData: (idUser, idGame) ->
        # Read (meta) data of given game
        promise = @_getGameData(idGame)

        # Read data of given player in given game
        promise = promise.then (gameData) =>
            gameDatabase = @_getGameDatabaseName(gameData)
            playerIdentitiesTable = @_getGameTableName(gameData, config.SQL_TABLES.GAME_PLAYER_IDENTITIES)
            sql = "
                    SELECT `I`.`ID` AS `game_identity_id`,
                           `I`.`Folkname` AS `game_identity_name`,
                           `I`.`LastActivityStamp` AS `activity_stamp`,
                           #{@_toQuery(gameData.game_title)} AS `game_title`
                    FROM `#{config.SQL_TABLES.PLAYER_GAMES}` AS `PG`
                    JOIN `#{gameDatabase}`.`#{playerIdentitiesTable}` AS `I`
                      ON `I`.`ID`=`PG`.`FolkID`
                    WHERE `PG`.`GalaxyID`=#{@_toQuery(idGame)}
                      AND `PG`.`UserID`=#{@_toQuery(idUser)}
                  "
            return @_readSimpleData(sql, true)

        # Read an identity sub id for cases where the fetched game identity is used by more than one player
        promise = promise.then (playerData) =>
            sql = "
                    SELECT `UserID` AS `user_id`
                    FROM `#{config.SQL_TABLES.PLAYER_GAMES}`
                    WHERE `GalaxyID`=#{@_toQuery(idGame)}
                      AND `FolkID`=#{@_toQuery(playerData.game_identity_id)}
                    ORDER BY `UserID` ASC
                  "
            innerPromise = @_readMultipleData(sql)
            innerPromise = innerPromise.then (identityPlayersListdata) =>
                if identityPlayersListdata.length > 1
                    playerItem = identityPlayersListdata.find (item, idx) ->
                        return ("#{item.user_id}" is "#{idUser}")
                    playerIndex = identityPlayersListdata.indexOf(playerItem)
                    playerData.game_identity_sub_id = playerIndex + 1  # Add sub id to result data
                return playerData
            return innerPromise

        # Build final result
        promise = promise.then (playerData) =>
            idSub = playerData.game_identity_sub_id or 0
            nameNumber = if idSub then "\##{idSub}" else ''
            return {
                id: "#{playerData.game_identity_id}_#{idSub}"
                idGame: idGame
                idUser: idUser
                name: "#{playerData.game_identity_name} #{nameNumber}".trim()
                title: "#{playerData.game_identity_name} - Player #{nameNumber}" if nameNumber
                gameTitle: playerData.game_title
                gameTag: @_getShortenedGameTitle(playerData.game_title)
                token: @_getSecurityToken(idUser, playerData)
            }

        return promise

    # @override
    _getSecurityToken: (idUser, playerData) ->
        return @_getHashValue("#{config.CLIENT_AUTH_SECRET}_#{idUser}_#{playerData.activity_stamp}")

    # @override
    _getShortenedGameTitle: (fullGameTitle) ->
        shortTitle = String(fullGameTitle)
        # Remove sub names (like 'Spiral'), but leave anything after a space (mostly numbers)
        shortTitle = shortTitle.replace(/(-[^- ]+)/, '')
        shortTitle = shortTitle.replace(/[\*]+/, '')  # Remove special marking chars
        return shortTitle


    #
    # Game-specific queries
    #

    # Returns the data for the given galaxy.
    # @override
    _getGameData: (idGame) ->
        sql = "
                SELECT `ID` AS `game_id`, `RealityID` AS `database_id`, `Galaxyname` AS `game_title`
                FROM `#{config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID`=#{@_toQuery(idGame)}
              "
        return @_readSimpleData(sql, true)

    # Returns the status information for each of the given list of galaxies.
    # @override
    getGameStatuses: (idList=[]) ->
        # Convert given array to string of comma-separated values
        idListSanitized = idList.map (idGame) =>
            @_toQuery(idGame)
        idListString = idListSanitized.join(',')

        # Read the status values for each game
        sql = "
                SELECT `ID` as `id`, `Status` AS `status`, `Round` AS `rounds`
                FROM `#{config.SQL_TABLES.GAMES_LIST}`
                WHERE `ID` IN (#{idListString})
                ORDER BY `Status` ASC, `ID` DESC
              "
        promise = @_readMultipleData(sql)
        promise = promise.then (dataList) =>
            statusTexts =
                '-1': 'Not released yet'
                '0': 'Not started yet'
                '1': 'Running'
                '2': 'Paused'
                '3': 'Finished / Terminated'
                '4': 'Evaluated and archived'
                '5': 'Running (aftermath)'
                '6': 'Paused (aftermath)'
                '7': 'Terminated and closed'

            # Fetch text for each status
            resultData = dataList.map (data) ->
                statusID = String(data?.status)
                data.status = statusTexts[statusID] or 'Unknown status'
                return data
            return resultData

        return promise

    # Returns the list of galaxies, which each have a bot to use for bot-channels.
    # If the mono-bot is configured, returns the list of almost all galaxies.
    # @override
    getBotRepresentedGames: ->
        if config.MAX_BOTS > 0
            sql = "
                    SELECT `ID` AS `id`, `Galaxyname` AS `title`
                    FROM `#{config.SQL_TABLES.GAMES_LIST}`
                    WHERE `Status`>=0 AND `Status`<4
                       OR `Status`=4 AND IFNULL(`FinishDateTime`, NOW()) >= (NOW() - INTERVAL 10 DAY)
                       OR `Status`>=5 AND `Status`<7
                    ORDER BY `Status` ASC, `ID` ASC
                    LIMIT #{config.MAX_BOTS}
                "
        else
            sql = "
                    SELECT `ID` AS `id`, `Galaxyname` AS `title`
                    FROM `#{config.SQL_TABLES.GAMES_LIST}`
                    WHERE `Status`>=0 AND `Status`<7
                       OR `Status`=7 AND IFNULL(`FinishDateTime`, 0) >= (NOW() - INTERVAL 60 DAY)
                    ORDER BY `Status` ASC, `ID` ASC
                "
        return @_readMultipleData(sql)



## Export class
module.exports = SgrDatasource

