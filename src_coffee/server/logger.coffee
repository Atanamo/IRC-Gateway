
## Include app modules
Config = require './config'


## Logger functions

getTimestamp = ->
    currDateTime = new Date()
    return currDateTime.toISOString().replace(/T|Z/g, ' ')


module.exports.info = (text...) ->
    console.log '#', getTimestamp(), text...

    #gateway_global.db.writeLog()

if Config.DEBUG_ENABLED
    module.exports.debug = (text...) ->
        console.log '=>', getTimestamp(), text...
else
    module.exports.debug = ->

module.exports.warn = (text, sender='General') ->
    console.warn "! #{getTimestamp()} Warning by #{sender}:", text

module.exports.error = (textOrError, sender='General') ->
    if textOrError instanceof Error
        textOrError = if textOrError.message? then textOrError.message else textOrError.toString?() or textOrError
    console.error "!! #{getTimestamp()} ERROR by #{sender}:", textOrError

