
## Include app modules
config = require './config'


## Abstraction to store and recognize flooding by a client.
##
class ClientFloodingRating
    floodingRecognizedCallback: null
    ratingEntries: null   # Array of objects: {'timestamp', 'weight'}*

    TIME_INTERVAL = config.FLOODRATE_TIME_INTERVAL  # Interval in milliseconds
    LIMIT_WEIGHT = config.FLOODRATE_LIMIT_WEIGHT    # Maximum total weight in interval

    constructor: (@floodingRecognizedCallback) ->
        @ratingEntries = []

    _addRatingEntry: (newWeight) ->
        @ratingEntries.push
            timestamp: Date.now()
            weight: newWeight
        return

    _calculateTotalWeightOfLatestEntries: ->
        intervalEntries = []
        nowTimestamp = Date.now()
        totalWeight = 0

        for currEntry in @ratingEntries by -1
            if nowTimestamp - currEntry.timestamp <= TIME_INTERVAL  # Must be younger than interval time
                intervalEntries.unshift(currEntry)  # Collect entries created within interval in chronological
                totalWeight += currEntry.weight     # Sum up weight of entries in interval
            else
                # Break at first entry outside interval
                break

        # Update ratings array
        @ratingEntries = intervalEntries

        return totalWeight

    checkForFlooding: (eventWeight) ->
        @_addRatingEntry(eventWeight)

        # Collect entries in interval and sum up their weight
        totalWeight = @_calculateTotalWeightOfLatestEntries()

        # Check limit
        if totalWeight > LIMIT_WEIGHT
            @floodingRecognizedCallback?()
            return false

        return true



## Export class
module.exports = ClientFloodingRating

