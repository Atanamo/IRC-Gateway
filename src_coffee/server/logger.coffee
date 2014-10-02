
## Include app modules
Config = require './config'


## Logger functions

module.exports.info = (text...) ->
    console.log '# ', text...

    #gateway_global.db.writeLog()

if Config.DEBUG_ENABLED
    module.exports.debug = (text...) ->
        console.debug '=> ', text...
else
    module.exports.debug = ->

module.exports.warn = (text, sender='General') ->
    console.warn "! Warning of #{sender}:", text

module.exports.error = (text, sender='General') ->
    console.error "! ERROR of #{sender}:", text

