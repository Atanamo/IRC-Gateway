
## Abstraction to store and recognize flooding by a client.
##
class ClientFloodingRating
    clientSocket: null
    ratingEntries: null   # Array of: [*{'timestamp', 'size'}]

    # Describes a rate limit of 1mb/s:
    LIMIT_SIZE = 1048576  # Maximum number of bytes/characters
    TIME_INTERVAL = 1000  # Interval in milliseconds

    constructor: (@clientSocket) ->
        @ratingEntries = []

    _addRatingEntry: (size) ->
        newEntry = 
            timestamp: Date.now()
            size: size
        @ratingEntries.push(newEntry)
        return newEntry

    _getEntriesWithinInterval: ->
        # Collect entries created within interval
        intervalEntries = []
        nowTimestamp = Date.now()

        for currEntry in @ratingEntries by -1
            if nowTimestamp - currEntry.timestamp < TIME_INTERVAL  # Must be younger than interval time
                intervalEntries.push(currEntry)

        return intervalEntries

    _getCalculatedTotalSize: (entries) ->
        totalSize = 0
        for currEntry in entries by 1
            totalSize += currEntry.size
        return totalSize


    checkForFlooding: (chunk) ->
        @_addRatingEntry(chunk.length)
        
        # Remove outdated entries / update array
        @ratingEntries = @_getEntriesWithinInterval()

        # Sum up size of entries in interval
        totalSize = @_getCalculatedTotalSize(@ratingEntries)

        # Check limit
        if totalSize > LIMIT_SIZE
            clientSocket.disconnect()  # TODO: Disconnect due to flooding.
            return false

        return true

    destroy: ->
        @clientSocket = null
        @ratingEntries = null



## Export class
module.exports = ClientFloodingProtection

