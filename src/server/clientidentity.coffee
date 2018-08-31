
## Include app modules
db = require './database'


## Abstraction of a client's identity.
## Used to identify clients and to store information to be sent to other clients.
## Instances have to be created by appropriate factory methods of the class.
##
class ClientIdentity
    id: 0
    idGame: 0
    idUser: 0
    name: 'Unknown'
    title: null
    gameTitle: ''
    gameTag: null
    isIrcClient: false
    securityToken: ''

    constructor: (data) ->
        for key, val of data
            @[key] = val
        @title = @name unless @title?
        @gameTag = @gameTitle unless @gameTag?

    @createFromIrcNick: (nickName, idGame=null) ->
        identObj = new ClientIdentity
            name: nickName
            title: "#{nickName} (IRC)"
            idGame: idGame
            isIrcClient: true
        return identObj

    @createFromDatabase: (idUser, idGame) ->
        promise = db.getClientIdentityData(idUser, idGame)
        promise = promise.then (data) =>
            return new ClientIdentity
                id: data.id
                idGame: data.idGame
                idUser: data.idUser
                name: data.name
                title: data.title
                gameTitle: data.gameTitle
                gameTag: data.gameTag
                securityToken: data.token
        return promise

    getName: ->
        return @name

    getID: ->
        return @id

    getGlobalID: ->
        return "#{@idGame}_#{@id}"

    getUserID: ->
        return @idUser

    getGameID: ->
        return @idGame

    getGameTitle: ->
        return @gameTitle

    getGameTag: ->
        return @gameTag

    toData: ->
        # Filter idUser and securityToken, because these must be secret to clients
        return {
            @id
            @idGame
            @name
            @title
            @gameTitle
            @gameTag
            @isIrcClient
        }



## Export class
module.exports = ClientIdentity

