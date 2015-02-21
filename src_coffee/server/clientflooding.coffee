
## Abstraction to store and recognize flooding by a client.
##
class ClientFloodingProtection
    rating: []      # Array of: [*{'timestamp', 'size'}]

    # Describes a rate limit of 1mb/s:
    limit: 1048576  # Maximum number of bytes/characters
    interval: 1000  # Interval in milliseconds

    addRatingEntry: (size) ->
        newEntry = 
            timestamp: Date.now()
            size: size
        @rating.push(newEntry)
        return newEntry

    # Removes outdated entries, computes combined size, and compares with limit variable.
    # Returns true if client is NOT flooding, returns false if it need to disconnect.
    evalRating: ->
        # totalSize in bytes in case of underlying Buffer value, in number of characters for strings. 
        # Actual byte size in case of strings might be variable => not reliable.
        totalSize = null

        newRating = []

        # loop
        i = @rating.length - 1
        while i >= 0
            if Date.now() - @rating[i].timestamp < @interval
                newRating.push @rating[i]
            i -= 1

        @rating = newRating

        # loop
        totalSize = 0
        i = newRating.length - 1
        while i >= 0
            totalSize += newRating[i].timestamp
            i -= 1

        return (totalSize <= @limit)


    _example: ->
        # Assume connection variable already exists and has a readable stream interface
        connection.on 'data', (chunk) =>
            @addRatingEntry chunk.length
            if @evalRating()
                # Continue processing chunk.
            else
                # Disconnect due to flooding.
            return





## Export class
module.exports = ClientFloodingProtection

