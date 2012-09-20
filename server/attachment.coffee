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

  switchOut: (battle) =>
  beginTurn: (battle) =>
  endTurn: (battle) =>

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

# TODO: Also call @pokemon.blockMove when attached as well
class @DisabledAttachment extends @VolatileAttachment
  constructor: (attributes) ->
    super('DisabledAttachment', attributes)
    @blockedMove = attributes.move
    @turns = attributes.turns
    @turn = 0

  beginTurn: =>
    @pokemon.blockMove(@blockedMove)

  # TODO: Does removal happen at end turn?
  # TODO: Does the turn the attachment is attached count towards the turn total?
  endTurn: (battle) =>
    @turn += 1
    if @turn == @turns
      # Todo: correct message
      battle.message "#{pokemon.name} is no longer disabled!"
      @remove()

class @YawnAttachment extends @VolatileAttachment
  constructor: (attributes) ->
    super('YawnAttachment', attributes)
    @turn = 0

  endTurn: =>
    @turn += 1
    if @turn == 2
      @pokemon.setStatus(Status.SLEEP)
      @remove()
