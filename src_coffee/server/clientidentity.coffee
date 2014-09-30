
class ClientIdentity
    id: 0
    idGame: 0
    name: 'Unknown'
    title: 'Unknown'
    isIrcClient: false

    constructor: (data) ->
        for key, val of data
            @[key] = val

    @createFromIrcNick: (nickName) ->
        identObj = new ClientIdentity
            name: nickName
            title: "#{nickName} (IRC)"
            isIrcClient: true

        return identObj

    @createFromDatabase: (id, idGame) ->
        # TODO: Get data from database, using given folk id

        identObj = new ClientIdentity
            id: 42
            name: 'TempName'
            #title: 'Temp Title'
            idGame: 123

        return identObj

    getName: ->
        return @name

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

