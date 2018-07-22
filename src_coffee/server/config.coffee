##
## Config loader ##
##

# Include configs
defaultConfig = require('./config.default')
customConfig = require('./config.custom')

# Bot version info
botVersion = 'v2.0'           # Bot's version number string
botLastUpdate = '2018-07-15'  # Update info for bot version

# Deep merge configs
fullConfig = Object.assign({}, defaultConfig, customConfig)
fullConfig.SQL_TABLES = Object.assign({}, defaultConfig.SQL_TABLES, customConfig.SQL_TABLES or {})

# Add hardcoded config
fullConfig.BOT_VERSION_STRING = "#{fullConfig.BOT_NAME}, #{botVersion} (Last update: #{botLastUpdate}) -- Created 2014 by Atanamo"


module.exports = fullConfig

