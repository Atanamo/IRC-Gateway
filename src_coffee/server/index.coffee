#
# Package main file
#

gatewayInstance = null

createGateway = ->
    unless gatewayInstance?
        Gateway = require './app'
        gatewayInstance = new Gateway()

    return gatewayInstance


module.exports = createGateway
