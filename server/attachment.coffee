{Status, VolatileStatus} = require './status'
util = require './util'
{_} = require 'underscore'

class @Attachments
  constructor: ->
    @attachments = []

  push: (attachmentClass, options={}) =>
    attachment = @get(attachmentClass)
    if !attachment?
      attachment = new attachmentClass(options)
      ## hacky
      attachment.pokemon = options.pokemon
      attachment.team = options.team
      ## end hacky
      @attachments.push(attachment)
      attachment.initialize()

    return false  if attachment.layers == attachment.maxLayers
    attachment.layers++
    return true

  # todo: should call Attachment#remove() somehow without causing infinite recursion
  unattach: (attachment) =>
    index = @indexOf(attachment)
    @attachments.splice(index, 1)

  indexOf: (attachment) =>
    @attachments.map((a) -> a.constructor).indexOf(attachment)

  get: (attachment) =>
    @attachments[@indexOf(attachment)]

  contains: (attachment) =>
    @indexOf(attachment) != -1

  queryUntil: (funcName, conditional, args...) =>
    for attachment in _.clone(@attachments)
      result = attachment[funcName](args...)  if funcName of attachment
      break  if conditional(result)
    result

  query: (funcName, args...) =>
    @queryUntil(funcName, (-> false), args...)

  queryUntilTrue: (funcName, args...) =>
    conditional = (result) -> result == true
    @queryUntil(funcName, conditional, args...)

  queryUntilFalse: (funcName, args...) =>
    conditional = (result) -> result == false
    @queryUntil(funcName, conditional, args...)

  queryUntilNotNull: (funcName, args...) =>
    conditional = (result) -> result?
    @queryUntil(funcName, conditional, args...)

  queryChain: (funcName, result) =>
    for attachment in _.clone(@attachments)
      result = attachment[funcName](result)  if funcName of attachment
    result

# Attachments represents a pokemon's state. Some examples are
# status effects, entry hazards, and fire spin's trapping effect.
# Attachments are "attached" with Pokemon.attach(), and after
# that the attachment can be retrieved with Attachment.pokemon
class @Attachment
  name: "Attachment"

  maxLayers: 1

  constructor: ->
    @layers = 0

  initialize: =>

  remove: =>
    # Error if @pokemon is undefined
    @pokemon.unattach(this)

  calculateWeight: (weight) => weight
  editAccuracy: (accuracy) => accuracy
  editEvasion: (evasion) => evasion
  afterBeingHit: (battle, move, user, target, damage) =>
  afterSuccessfulHit: (battle, move, user, target, damage) =>
  beforeMove: (battle, move, user, targets) =>
  isImmune: (battle, type) =>
  switchOut: (battle, pokemon) =>
  switchIn: (battle, pokemon) =>
  beginTurn: (battle) =>
  endTurn: (battle) =>
  update: (battle, owner) =>
  # editBoosts: =>

  # Pokemon-specific attachments
  # TODO: Turn Attachment into abstract class
  # TODO: Move into own PokemonAttachment
  modifyHp: (stat) => stat
  modifySpeed: (stat) => stat
  modifyAccuracy: (stat) => stat
  modifyEvasion: (stat) => stat
  modifyAttack: (stat) => stat
  modifySpecialAttack: (stat) => stat
  modifyDefense: (stat) => stat
  modifySpecialDefense: (stat) => stat

Attachment = @Attachment

class @TeamAttachment extends @Attachment
  name: "TeamAttachment"

  remove: =>
    @team.unattach(this)

class @Attachment.Paralysis extends @Attachment
  name: Status.PARALYZE

  beforeMove: (battle, move, user, targets) =>
    if battle.rng.next('paralyze chance') < .25
      battle.message "#{@pokemon.name} is fully paralyzed!"
      return false

  modifySpeed: (stat) =>
    Math.floor(stat / 4)

class @Attachment.Freeze extends @Attachment
  name: Status.FREEZE

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
  name: VolatileStatus.FLINCH

  beforeMove: (battle, move, user, targets) =>
    battle.message "#{@pokemon.name} flinched!"
    false

  endTurn: =>
    @remove()

class @Attachment.Confusion extends @VolatileAttachment
  name: VolatileStatus.CONFUSION

  constructor: (attributes={}) ->
    super()
    @turns = attributes.battle.rng.randInt(1, 4, "confusion turns")
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
class @Attachment.Disable extends @VolatileAttachment
  name: "DisableAttachment"

  constructor: (attributes={}) ->
    super()
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
  name: 'YawnAttachment'

  constructor: ->
    super()
    @turn = 0

  endTurn: =>
    @turn += 1
    if @turn == 2
      @pokemon.setStatus(Status.SLEEP)
      @remove()

# TODO: Does weight get lowered if speed does not change?
class @Attachment.Autotomize extends @VolatileAttachment
  name: "AutotomizeAttachment"

  maxLayers: -1

  calculateWeight: (weight) =>
    Math.max(weight - 100 * @layers, .1)

class @Attachment.Nightmare extends @VolatileAttachment
  name: "NightmareAttachment"

  endTurn: (battle) =>
    if @pokemon.hasStatus(Status.SLEEP)
      battle.message "#{@pokemon.name} is locked in a nightmare!"
      @pokemon.damage Math.floor(@pokemon.stat('hp') / 4)
    else
      @remove()

class @Attachment.Taunt extends @VolatileAttachment
  name: "TauntAttachment"

  constructor: (attributes={}) ->
    super()
    {@battle} = attributes
    @turns = 3
    @turn = 0

  beginTurn: (battle) =>
    for move in @pokemon.moves
      if move.power == 0
        @pokemon.blockMove(move)

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

  remove: =>
    delete @battle
    super()

class @Attachment.Wish extends @TeamAttachment
  name: "WishAttachment"

  constructor: (attributes) ->
    super()
    {user, @team} = attributes
    @amount = Math.round(user.stat('hp') / 2)
    @wisherName = user.name
    @slot = @team.indexOf(user)
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

  remove: =>
    delete @battle
    super()

class @Attachment.PerishSong extends @VolatileAttachment
  name: "PerishSongAttachment"

  constructor: ->
    super()
    @turns = 4
    @turn = 0

  endTurn: (battle) =>
    @turn++
    battle.message "#{@pokemon.name}'s perish count fell to #{@turns - @turn}!"
    if @turn >= @turns
      @pokemon.faint()
      battle.message "#{@pokemon.name} fainted!"

class @Attachment.Roost extends @VolatileAttachment
  name: "RoostAttachment"

  initialize: =>
    @oldTypes = @pokemon.types
    @pokemon.types = (type for type in @pokemon.types when type != 'Flying')
    if @pokemon.types.length == 0 then @pokemon.types = [ 'Normal' ]

  endTurn: (battle) =>
    @pokemon.types = @oldTypes
    @remove()

class @Attachment.Encore extends @VolatileAttachment
  name: "EncoreAttachment"

  constructor: ->
    super()
    @turns = 3
    @turn = 0

  initialize: =>
    @move = @pokemon.lastMove

  beginTurn: (battle) =>
    @pokemon.lockMove(@move)

  endTurn: (battle) =>
    @turn++
    if @turn >= @turns || @pokemon.pp(@move) == 0
      battle.message("#{@pokemon.name}'s Encore ended!")
      @remove()

class @Attachment.Torment extends @VolatileAttachment
  name: "TormentAttachment"

  beginTurn: (battle) =>
    @pokemon.blockMove(@pokemon.lastMove)  if @pokemon.lastMove?

class @Attachment.ChoiceLock extends @VolatileAttachment
  name: "ChoiceLockAttachment"

  initialize: =>
    @move = null

  beforeMove: (battle, move, user, targets) =>
    @move = move
    true

  beginTurn: (battle) =>
    @pokemon.lockMove(@move)  if @move?

  remove: =>
    delete @move
    super()

class @Attachment.IronBall extends @Attachment
  name: "IronBallAttachment"

  isImmune: (battle, type) =>
    return false  if type == 'Ground'

class @Attachment.AirBalloon extends @Attachment
  name: "AirBalloonAttachment"

  afterBeingHit: (battle, move, user, target, damage) =>
    return  if move.isNonDamaging()
    battle.message "#{target.name}'s #{target.getItem().name} popped!"
    target.removeItem()

  isImmune: (battle, type) =>
    return true  if type == 'Ground'

class @Attachment.Spikes extends @TeamAttachment
  name: "SpikesAttachment"

  maxLayers: 3

  switchIn: (battle, pokemon) =>
    return  if pokemon.isImmune(battle, "Ground")
    fraction = (10 - 2 * @layers)
    hp = pokemon.stat('hp')
    pokemon.damage Math.floor(hp / fraction)

class @Attachment.StealthRock extends @TeamAttachment
  name: "StealthRockAttachment"

  switchIn: (battle, pokemon) =>
    multiplier = util.typeEffectiveness("Rock", pokemon.types)
    hp = pokemon.stat('hp')
    pokemon.damage Math.floor(hp * multiplier / 8)

class @Attachment.ToxicSpikes extends @TeamAttachment
  name: "ToxicSpikesAttachment"

  maxLayers: 2

  switchIn: (battle, pokemon) =>
    if pokemon.hasType("Poison") && !pokemon.isImmune(battle, "Ground")
      name = battle.getOwner(pokemon).username
      battle.message "The poison spikes disappeared from around #{name}'s team's feet!"
      @remove()

    return  if pokemon.isImmune(battle, "Poison")

    if @layers == 1
      pokemon.setStatus(Status.POISON)
    else
      pokemon.setStatus(Status.TOXIC)

# A trap created by Fire Spin, Magma Storm, Bind, Clamp, etc
class @Attachment.Trap extends @VolatileAttachment
  name: "TrapAttachment"

  constructor: (attributes={}) ->
    super()
    {@moveName, @user, @turns} = attributes

  beginTurn: (battle) =>
    @pokemon.blockSwitch()

  endTurn: (battle) =>
    # For the first numTurns turns it will damage, and at numTurns + 1 it will wear off.
    # Therefore, if @turns = 5, this attachment should actually last for 6 turns.
    if @turns == 0
      battle.message "#{@pokemon.name} was freed from #{@moveName}!"
      @remove()
    else
      battle.message "#{@pokemon.name} is hurt by #{@moveName}!"
      @pokemon.damage Math.floor(@pokemon.stat('hp') / @getDamagePerTurn())
      @turns -= 1

  getDamagePerTurn: =>
    if @user.hasItem("Binding Band")
      8
    else
      16

  remove: =>
    @user.unattach(Attachment.TrapLeash)
    delete @user
    super()

# If the creator if fire spin switches out, the trap will end
# TODO: What happens if another ability removes the trap, and then firespin is used again?
class @Attachment.TrapLeash extends @VolatileAttachment
  name: "TrapLeashAttachment"

  constructor: (attributes={}) ->
    super()
    {@target} = attributes

  remove: =>
    @target.unattach(Attachment.Trap)
    delete @target
    super()

# Has a 50% chance to immobilize a Pokemon before it moves.
class @Attachment.Attract extends @VolatileAttachment
  name: "AttractAttachment"

  constructor: (attributes={}) ->
    super()
    {@source} = attributes

  initialize: =>
    if @pokemon.hasItem("Destiny Knot") && !@source.hasAttachment(Attachment.Attract)
      @source.attach(Attachment.Attract, {@source})
      @pokemon.removeItem()

  beforeMove: (battle, move, user, targets) =>
    if battle.rng.next('attract chance') < .5
      battle.message "#{@pokemon.name} is immobilized by love!"
      return false

class @Attachment.FocusEnergy extends @VolatileAttachment
  name: "FocusEnergyAttachment"

class @Attachment.MicleBerry extends @VolatileAttachment
  name: "MicleBerryAttachment"
  constructor: ->
    super()
    @turns = 1

  editAccuracy: (accuracy) =>
    Math.floor(accuracy * 1.2)

  endTurn: (battle) =>
    if @turns == 0
      @remove()
    else
      @turns--

class @Attachment.EvasionItem extends @VolatileAttachment
  name: "EvasionItemAttachment"

  constructor: (attributes={}) ->
    super()
    @ratio = attributes.ratio || 0.9

  editEvasion: (accuracy) =>
    Math.floor(accuracy * @ratio)

class @Attachment.Metronome extends @VolatileAttachment
  name: "MetronomeAttachment"

  maxLayers: 5

  constructor: (attributes={}) ->
    super()
    {@move} = attributes

class @Attachment.Screen extends @TeamAttachment
  name: "ScreenAttachment"

  constructor: (attributes={}) ->
    super(attributes)
    {user} = attributes
    @turns = (if user?.hasItem("Light Clay") then 8 else 5)

  endTurn: (battle) =>
    @turns--
    if @turns == 0
      @remove()

class @Attachment.Reflect extends @Attachment.Screen
  name: "ReflectAttachment"

class @Attachment.LightScreen extends @Attachment.Screen
  name: "LightScreenAttachment"

class @Attachment.Identify extends @VolatileAttachment
  name: "IdentifyAttachment"

  constructor: (attributes={}) ->
    super(attributes)
    {@type} = attributes

  editBoosts: (stages) =>
    stages.evasion = 0
    stages

  isImmune: (battle, type) =>
    return false  if type == @type

class @Attachment.DefenseCurl extends @VolatileAttachment
  name: "DefenseCurl"

class @Attachment.FocusPunch extends @VolatileAttachment
  name: "FocusPunchAttachment"

  beforeMove: (battle, move, user, targets) =>
    if user.lastHitBy? && !user.lastHitBy.move.isNonDamaging()
      battle.message "#{user.name} lost its focus and couldn't move!"
      return false

class @Attachment.MagnetRise extends @VolatileAttachment
  name: "MagnetRiseAttachment"

  constructor: ->
    super()
    @turns = 5

  isImmune: (battle, type) =>
    return true  if type == "Ground"

  endTurn: (battle) =>
    @turns -= 1
    @remove()  if @turns == 0
