
## Include app modules
Config = require './config'


## Logger functions

module.exports.info = (text...) ->
    console.log '# ', text...

    #gateway_global.db.writeLog()

module.exports.warn = (text, sender='General') ->
    console.warn '! Warning in #{sender}: #{text}'

module.exports.error = (text, sender='General') ->
    console.error '! ERROR in #{sender}: #{text}!'

