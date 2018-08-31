
# Include datasource loader
loader = require './datasources/loader'

# Get the last set datasource class
DatasourceClass = loader.get()

# Export as singleton
module.exports = new DatasourceClass()

