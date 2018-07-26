##
## Config loader ##
##

# Include default config
defaultConfig = require('./config.default')


# Helper functions
isObject = (value) ->
    return value and typeof value is 'object' and value.constructor is Object


# Bot version info
botVersion = 'v2.0'           # Bot's version number string
botLastUpdate = '2018-07-15'  # Update info for bot version

getBotVersionString = (config) ->
    "#{config.BOT_NAME}, #{botVersion} (Last update: #{botLastUpdate}) -- Created 2014 by Atanamo"


# Set up config
configWrap = defaultConfig
configWrap.BOT_VERSION_STRING = getBotVersionString(configWrap)

configWrap._overwriteDefaults = (customConfig) ->
    return unless customConfig? and isObject(customConfig)

    # Deep merge configs
    for key, setting of customConfig
        if isObject(setting)
            configWrap[key] = Object.assign({}, defaultConfig[key] or {}, setting)
        else
            configWrap[key] = setting

    # Update version string
    configWrap.BOT_VERSION_STRING = getBotVersionString(configWrap)


# Export config wrap
module.exports = configWrap

