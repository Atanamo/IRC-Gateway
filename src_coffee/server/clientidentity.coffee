
class ClientIdentity
    id: 0
    idGame: 0
    name: 'Unknown'
    title: null
    isIrcClient: false

    constructor: (data) ->
        for key, val of data
            @[key] = val
        @title = @name unless @title?

    @createFromIrcNick: (nickName) ->
        identObj = new ClientIdentity
            name: nickName
            title: "#{nickName} (IRC)"
            isIrcClient: true

        return identObj

    @createFromDatabase: (id, idGame) ->
        # TODO: Get data from database, using given folk id
        promise = db.getClientIdentityData(id, idGame)
        promise = promise.then (data) =>
            return new ClientIdentity
                id: data.id
                name: data.name
                #title: 'Temp Title'
                idGame: data.idGame

        return promise

    getName: ->
        return @name

    getID: ->
        return @id

    getGameID: ->
        return @idGame

    getGlobalID: ->
        return "#{@idGame}_#{@id}"

    toData: ->
        data = {}
        for key, val of this
            data[key] = val unless typeof(val) is 'function'
        return data



## Export class
module.exports = ClientIdentity

