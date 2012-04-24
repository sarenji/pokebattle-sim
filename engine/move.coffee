class @Move
  constructor: (@name, attributes = {}) ->
    @priority = attributes.priority || 0
