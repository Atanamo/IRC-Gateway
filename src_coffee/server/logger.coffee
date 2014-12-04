
## Include app modules
Config = require './config'


## Logger functions

module.exports.info = (text...) ->
    console.log '# ', text...

    #gateway_global.db.writeLog()

if Config.DEBUG_ENABLED
    module.exports.debug = (text...) ->
        console.log '=> ', text...
else
    module.exports.debug = ->

module.exports.warn = (text, sender='General') ->
    console.warn "! Warning by #{sender}:", text

module.exports.error = (textOrError, sender='General') ->
    if textOrError instanceof Error
        textOrError = if textOrError.message? then textOrError.message else textOrError.toString?() or textOrError
    console.error "! ERROR by #{sender}:", textOrError

