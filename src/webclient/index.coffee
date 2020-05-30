
Translation = require './translate_module'
ChatController = require './chat_controller'


# Create wrapper class for ChatController in global namespace
class GatewayChat
    controller = null

    constructor: (args...) ->
        # Setup the translations for browser's language
        Translation.setup()

        # Create the main controller
        controller = new ChatController(args...)

    start: ->
        controller.start()

    setTabContentVisibilityInfo: (args...) ->
        controller.start(args...)


# Export webclient, translation module and selector lib
module.exports = GatewayChat
module.exports.Translation = Translation
module.exports.$ = ChatController.$
