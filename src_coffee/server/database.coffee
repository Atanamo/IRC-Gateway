
# Include database loader
loader = require './databaseloader'

# Get the last set database class
DatabaseClass = loader.get()

# Export as singleton
module.exports = new DatabaseClass()

