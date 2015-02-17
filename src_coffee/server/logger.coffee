
## Include app modules
Config = require './config'


## Logger functions

getTimestamp = ->
    currDateTime = new Date()
    dateTimeString = currDateTime.toISOString().replace(/T|Z/g, ' ').trim()
    return "[#{dateTimeString}]"


if Config.DEBUG_ENABLED
    module.exports.debug = (text...) ->
        console.log '=>', getTimestamp(), text...
else
    module.exports.debug = ->

module.exports.info = (text...) ->
    console.log '#', getTimestamp(), text...

module.exports.warn = (text, sender='General') ->
    console.warn "! #{getTimestamp()} Warning by #{sender}:", text

module.exports.error = (textOrError, sender='General') ->
    if textOrError instanceof Error
        errObject = textOrError
        textOrError = if errObject.message? then errObject.message else errObject.toString?() or errObject
    console.error "!! #{getTimestamp()} ERROR by #{sender}:", textOrError
    if errObject?
        console.error ''
        console.error(errObject.stack)
        console.error ''
