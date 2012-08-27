{Status} = require './status'

class @Attachment
  constructor: (name, attributes) ->
    @name = name
    {@duration} = attributes

  afterTurn: =>

class @BurnAttachment extends @Attachment
  constructor: (attributes={}) ->
    super(Status.BURN, attributes)
