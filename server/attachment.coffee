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

  calculateWeight: (weight) =>
  beforeMove: (battle, move, user, targets) =>
  switchOut: (battle) =>
  beginTurn: (battle) =>
  endTurn: (battle) =>

class @TeamAttachment extends @Attachment
  constructor: (name, attributes) ->
    super(name, attributes)
    @team = attributes.team

  remove: =>
    @team.unattach(this)


class @Attachment.Freeze extends @Attachment
  constructor: (attributes={}) ->
    super(Status.FREEZE, attributes)

  beforeMove: (battle, move, user, targets) =>
    if move.thawsUser || battle.rng.next('unfreeze chance') < .2
      battle.message "#{@pokemon.name} thawed out!"
      @remove()
    else
      battle.message "#{@pokemon.name} is frozen solid!"
      return false

# An attachment that removes itself when a pokemon
# deactivates.
class @VolatileAttachment extends @Attachment
  switchOut: =>
    @remove()

class @Attachment.Flinch extends @VolatileAttachment
  constructor: (attributes={}) ->
    super(VolatileStatus.FLINCH, attributes)

  beforeMove: (battle, move, user, targets) =>
    battle.message "#{@pokemon.name} flinched!"
    false

  endTurn: =>
    @remove()

class @Attachment.Confusion extends @VolatileAttachment
  constructor: (attributes) ->
    super(VolatileStatus.CONFUSION, attributes)
    @turns = attributes.turns
    @turn = 0

  beforeMove: (battle, move, user, targets) =>
    battle.message "#{@pokemon.name} is confused!"
    @turn++
    if @turn > @turns
      battle.message "#{@pokemon.name} snapped out of confusion!"
      @remove()
    else if battle.rng.next('confusion') < 0.5
      battle.message "#{@pokemon.name} hurt itself in confusion!"
      damage = battle.confusionMove.calculateDamage(battle, user, user)
      user.damage(damage)
      return false

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

# TODO: Does weight get lowered if speed does not change?
class @Attachment.Autotomize extends @VolatileAttachment
  constructor: (attributes={}) ->
    super("AutotomizeAttachment", attributes)

  calculateWeight: (weight) =>
    Math.max(weight - 100, .1)

class @Attachment.Nightmare extends @VolatileAttachment
  constructor: (attributes={}) ->
    super("NightmareAttachment", attributes)

  endTurn: (battle) =>
    if @pokemon.hasStatus(Status.SLEEP)
      battle.message "#{@pokemon.name} is locked in a nightmare!"
      @pokemon.damage Math.floor(@pokemon.stat('hp') / 4)
    else
      @remove()

class @Attachment.Taunt extends @VolatileAttachment
  constructor: (attributes={}) ->
    super("TauntAttachment", attributes)
    @battle = attributes.battle
    @turns = 3
    @turn = 0

  beginTurn: (battle) =>
    for moveName in @pokemon.moves
      move = battle.getMove(moveName)
      if move.power == 0
        @pokemon.blockMove(moveName)

  beforeMove: (battle, move, user, targets) =>
    # TODO: user is always == pokemon. Will this change?
    if user == @pokemon && move.power == 0
      battle.message "#{@pokemon.name} can't use #{move.name} after the taunt!"
      return false

  endTurn: (battle) =>
    @turn++
    if @turn >= @turns
      battle.message "#{@pokemon.name}'s taunt wore off!"
      @remove()

class @Attachment.Wish extends @TeamAttachment
  constructor: (attributes={}) ->
    super("WishAttachment", attributes)
    {user, team} = attributes
    @amount = Math.round(user.stat('hp') / 2)
    @wisherName = user.name
    @slot = team.indexOf(user)
    @turns = 2
    @turn = 0

  endTurn: (battle) =>
    @turn++
    if @turn >= @turns
      pokemon = @team.at(@slot)
      if !pokemon.isFainted()
        battle.message "#{@wisherName}'s wish came true!"
        pokemon.damage(-@amount)
      @remove()
