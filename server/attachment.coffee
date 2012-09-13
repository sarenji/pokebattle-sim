{Status, VolatileStatus} = require './status'

# Attachments represents a pokemon's state. Some examples are
# status effects, entry hazards, and fire spin's trapping effect.
# Attachments are "attached" with Pokemon.attach(), and after
# that the attachment can be retrieved with Attachment.pokemon
class @Attachment
  constructor: (name, attributes={}) ->
    @name = name
    {@duration} = attributes

  remove: =>
    # Error if @pokemon is undefined
    @pokemon.unattach(this)

  switchOut: =>
  endTurn: =>

# An attachment that removes itself when a pokemon
# deactivates.
class @VolatileAttachment extends @Attachment
  switchOut: =>
    @remove()

class @FlinchAttachment extends @Attachment
  constructor: (attributes={}) ->
    attributes.duration ||= 1
    super(VolatileStatus.FLINCH, attributes)

class @ConfusionAttachment extends @VolatileAttachment
  constructor: (attributes) ->
    super(VolatileStatus.CONFUSION, attributes)

class @YawnAttachment extends @VolatileAttachment
  constructor: (attributes) ->
    super('YawnAttachment', attributes)
    @turn = 0

  endTurn: =>
    @turn += 1
    if @turn == 2
      @pokemon.setStatus(Status.SLEEP)
      @remove()
