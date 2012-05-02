class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @priority = attributes.priority || 0

  # Executes the move on the target. Target may be null
  # if the move attacks all opponents
  execute: (target) ->
    # todo: Emit this on the battlefield
    @beforeMove?()
    # actual move goes here
    @afterMove?()

