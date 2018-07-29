
## Include app modules
config = require './config'


## Logger functions

getTimestamp = ->
    currDateTime = new Date()
    dateTimeString = currDateTime.toISOString().replace(/T|Z/g, ' ').trim()
    return "[#{dateTimeString}]"


module.exports.debug = (text...) ->
    if config.DEBUG_ENABLED
        console.log '=>', getTimestamp(), text...

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

