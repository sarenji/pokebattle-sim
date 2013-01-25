{Status, VolatileStatus} = require './status'

# Attachments represents a pokemon's state. Some examples are
# status effects, entry hazards, and fire spin's trapping effect.
# Attachments are "attached" with Pokemon.attach(), and after
# that the attachment can be retrieved with Attachment.pokemon
class @Attachment
  constructor: (name, attributes={}) ->
    @name = name

  remove: =>
    # Error if @pokemon is undefined
    @pokemon.unattach(this)

  beforeMove: (battle, move) =>
  switchOut: (battle) =>
  beginTurn: (battle) =>
  endTurn: (battle) =>

# An attachment that removes itself when a pokemon
# deactivates.
class @VolatileAttachment extends @Attachment
  switchOut: =>
    @remove()

class @Attachment.Flinch extends @VolatileAttachment
  constructor: (attributes={}) ->
    super(VolatileStatus.FLINCH, attributes)

  beforeMove: (battle, move) =>
    battle.message "#{@pokemon.name} flinched!"
    false

  endTurn: =>
    @remove()

class @Attachment.Confusion extends @VolatileAttachment
  constructor: (attributes) ->
    super(VolatileStatus.CONFUSION, attributes)

# TODO: Also call @pokemon.blockMove when attached as well
class @Attachment.Disabled extends @VolatileAttachment
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
    if @turn >= @turns
      battle.message "#{@pokemon.name} is no longer disabled!"
      @remove()

class @Attachment.Yawn extends @VolatileAttachment
  constructor: (attributes) ->
    super('YawnAttachment', attributes)
    @turn = 0

  endTurn: =>
    @turn += 1
    if @turn == 2
      @pokemon.setStatus(Status.SLEEP)
      @remove()
