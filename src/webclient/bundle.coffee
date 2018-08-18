
# Backup partial classes
partialClassesMap = this.GatewayChat or {}


# Create wrapper class for ChatController in global namespace
class this.GatewayChat
    controller = null

    constructor: (args...) ->
        controller = new ChatController(args...)

    start: ->
        controller.start()

    setTabContentVisibilityInfo: (args...) ->
        controller.start(args...)


# Add partial classes to wrapper class as props - Allows to use the wrapper like a namespace
for name, clazz of partialClassesMap
    this.GatewayChat[name] = clazz

