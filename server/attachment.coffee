{Protocol} = require '../shared/protocol'
{Weather} = require './weather'
util = require './util'
{_} = require 'underscore'

@Attachment = Attachment = {}
@Status = Status = {}

class @Attachments
  constructor: ->
    @attachments = []

  push: (attachmentClass, options={}, attributes={}) ->
    throw new Error("Passed a non-existent Attachment.")  if !attachmentClass?
    return null  if @queryUntilFalse('shouldAttach', attachmentClass) == false
    return null  if attachmentClass.preattach?(options, attributes) == false
    attachment = @get(attachmentClass)
    if !attachment?
      attachment = new attachmentClass()
      for attribute, value of attributes
        attachment[attribute] = value
      @attachments.push(attachment)
      attachment.initialize?(options)

    return null  if attachment.layers == attachment.maxLayers
    attachment.layers++
    return attachment

  unattach: (klass) ->
    index = @indexOf(klass)
    if index >= 0
      attachment = @attachments.splice(index, 1)[0]
      attachment.unattach?()
      attachment.attached = false
      attachment

  unattachAll: (condition) ->
    condition ||= -> true
    length = @attachments.length
    i = 0
    while i < length
      attachment = @attachments[i]
      if condition(attachment)
        attachment.unattach?()
        @attachments.splice(i, 1)
        length--
      else
        i++

  # Returns a list of attachments that can be passed to another Pokemon.
  getPassable: ->
    passable = @attachments.filter((attachment) -> attachment.passable)
    passable.map((a) -> a.constructor)

  indexOf: (attachment) ->
    @attachments.map((a) -> a.constructor).indexOf(attachment)

  get: (attachment) ->
    @attachments[@indexOf(attachment)]

  contains: (attachment) ->
    @indexOf(attachment) != -1

  queryUntil: (funcName, conditional, args...) ->
    for attachment in _.clone(@attachments)
      continue  if !attachment.valid()
      if funcName of attachment
        result = attachment[funcName].apply(attachment, args)
      break  if conditional(result)
    result

  query: (funcName, args...) ->
    @queryUntil(funcName, (-> false), args...)

  queryUntilTrue: (funcName, args...) ->
    conditional = (result) -> result == true
    @queryUntil(funcName, conditional, args...)

  queryUntilFalse: (funcName, args...) ->
    conditional = (result) -> result == false
    @queryUntil(funcName, conditional, args...)

  queryUntilNotNull: (funcName, args...) ->
    conditional = (result) -> result?
    @queryUntil(funcName, conditional, args...)

  queryChain: (funcName, result, args...) ->
    for attachment in _.clone(@attachments)
      result = attachment[funcName].call(attachment, result, args...)  if funcName of attachment
    result

  queryModifiers: (funcName, args...) ->
    result = 0x1000
    for attachment in _.clone(@attachments)
      continue  unless funcName of attachment
      modifier = attachment[funcName](args...)
      result = Math.floor((result * modifier + 0x800) / 0x1000)
    result

  all: ->
    _.clone(@attachments)

# Attachments represents a pokemon's state. Some examples are
# status effects, entry hazards, and fire spin's trapping effect.
# Attachments are "attached" with Pokemon.attach(), and after
# that the attachment can be retrieved with Attachment.pokemon
class @BaseAttachment
  name: "BaseAttachment"

  maxLayers: 1

  constructor: ->
    @layers = 0
    @attached = true

  valid: ->
    return false  if !@attached
    return false  if @item && @pokemon?.item && @pokemon?.isItemBlocked()
    return false  if @pokemon && !@pokemon.isAlive()
    return true

  # initialize: ->
  # unattach: ->
  # calculateWeight: (weight) -> weight
  # afterBeingHit: (move, user, target, damage) ->
  # afterSuccessfulHit: (move, user, target, damage) ->
  # beforeMove: (move, user, targets) ->
  # isImmune: (type) ->
  # switchOut: ->
  # switchIn: ->
  # beginTurn: ->
  # endTurn: ->
  # update: (owner) ->
  # editBoosts: (stages) ->
  # editDamage: (damage, move, user) ->
  # afterFaint: ->
  # shouldBlockExecution: (move, user) ->

  # Pokemon-specific attachments
  # TODO: Turn Attachment into abstract class
  # TODO: Move into own PokemonAttachment
  # editHp: (stat) -> stat
  # editAttack: (stat) -> stat
  # editSpeed: (stat) -> stat
  # editSpecialAttack: (stat) -> stat
  # editDefense: (stat) -> stat
  # editSpecialDefense: (stat) -> stat

# Used for effects like Tailwind or Reflect.
class @TeamAttachment extends @BaseAttachment
  name: "TeamAttachment"

# Used for effects like Trick Room or Magic Room.
class @BattleAttachment extends @BaseAttachment
  name: "BattleAttachment"

# An attachment that removes itself when a pokemon
# deactivates.
class @VolatileAttachment extends @BaseAttachment
  name: "VolatileAttachment"
  volatile: true

class @Attachment.Flinch extends @VolatileAttachment
  name: "FlinchAttachment"

  beforeMove: (move, user, targets) ->
    @battle.message "#{@pokemon.name} flinched!"
    @pokemon.boost(speed: 1)  if @pokemon.hasAbility("Steadfast")
    false

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Confusion extends @VolatileAttachment
  name: "ConfusionAttachment"
  passable: true

  initialize: (attributes) ->
    @turns = @battle?.rng.randInt(1, 4, "confusion turns") || 1
    @turn = 0

  beforeMove: (move, user, targets) ->
    @battle.message "#{@pokemon.name} is confused!"
    @turn++
    if @turn > @turns
      @battle.message "#{@pokemon.name} snapped out of confusion!"
      @pokemon.unattach(@constructor)
    else if @battle.rng.next('confusion') < 0.5
      @battle.message "#{@pokemon.name} hurt itself in confusion!"
      damage = @battle.confusionMove.calculateDamage(@battle, user, user)
      user.damage(damage)
      return false

class @Attachment.Disable extends @VolatileAttachment
  name: "DisableAttachment"

  initialize: (attributes) ->
    @blockedMove = attributes.move
    @turns = 4

  beginTurn: ->
    @pokemon.blockMove(@blockedMove)

  beforeMove: (move, user, target) ->
    if move == @blockedMove
      @battle.message "#{@pokemon.name}'s #{move.name} is disabled!"
      return false

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "#{@pokemon.name} is no longer disabled!"
      @pokemon.unattach(@constructor)

class @Attachment.Yawn extends @VolatileAttachment
  name: 'YawnAttachment'

  initialize: ->
    @turn = 0

  endTurn: ->
    @turn += 1
    if @turn == 2
      @pokemon.attach(Status.Sleep)
      @pokemon.unattach(@constructor)

# TODO: Does weight get lowered if speed does not change?
class @Attachment.Autotomize extends @VolatileAttachment
  name: "AutotomizeAttachment"

  maxLayers: -1

  calculateWeight: (weight) ->
    Math.max(weight - 100 * @layers, .1)

class @Attachment.Nightmare extends @VolatileAttachment
  name: "NightmareAttachment"

  endTurn: ->
    if @pokemon.has(Status.Sleep)
      @battle.message "#{@pokemon.name} is locked in a nightmare!"
      @pokemon.damage Math.floor(@pokemon.stat('hp') / 4)
    else
      @pokemon.unattach(@constructor)

class @Attachment.Taunt extends @VolatileAttachment
  name: "TauntAttachment"

  initialize: (attributes) ->
    @turns = 3
    @turn = 0

  beginTurn: ->
    for move in @pokemon.moves
      if move.power == 0
        @pokemon.blockMove(move)

  beforeMove: (move, user, targets) ->
    # TODO: user is always == pokemon. Will this change?
    if user == @pokemon && move.power == 0
      @battle.message "#{@pokemon.name} can't use #{move.name} after the taunt!"
      return false

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.message "#{@pokemon.name}'s taunt wore off!"
      @pokemon.unattach(@constructor)

class @Attachment.Wish extends @TeamAttachment
  name: "WishAttachment"

  initialize: (attributes) ->
    {user} = attributes
    @amount = Math.round(user.stat('hp') / 2)
    @wisherName = user.name
    @slot = @team.indexOf(user)
    @turns = 2
    @turn = 0

  endTurn: ->
    @turn++
    if @turn >= @turns
      pokemon = @team.at(@slot)
      if !pokemon.isFainted()
        @battle.message "#{@wisherName}'s wish came true!"
        pokemon.damage(-@amount)
      @team.unattach(@constructor)

class @Attachment.PerishSong extends @VolatileAttachment
  name: "PerishSongAttachment"
  passable: true

  initialize: ->
    @turns = 4
    @turn = 0

  endTurn: ->
    @turn++
    @battle.message "#{@pokemon.name}'s perish count fell to #{@turns - @turn}!"
    if @turn >= @turns
      @pokemon.faint()
      @pokemon.unattach(@constructor)

class @Attachment.Roost extends @VolatileAttachment
  name: "RoostAttachment"

  initialize: ->
    @oldTypes = @pokemon.types
    @pokemon.types = (type for type in @pokemon.types when type != 'Flying')
    if @pokemon.types.length == 0 then @pokemon.types = [ 'Normal' ]

  endTurn: ->
    @pokemon.types = @oldTypes
    @pokemon.unattach(@constructor)

class @Attachment.Encore extends @VolatileAttachment
  name: "EncoreAttachment"

  initialize: ->
    @turns = 3
    @turn = 0
    @move = @pokemon.lastMove

  beginTurn: ->
    @pokemon.lockMove(@move)

  endTurn: ->
    @turn++
    if @turn >= @turns || @pokemon.pp(@move) == 0
      @battle.message("#{@pokemon.name}'s Encore ended!")
      @pokemon.unattach(@constructor)

class @Attachment.Torment extends @VolatileAttachment
  name: "TormentAttachment"

  beginTurn: ->
    @pokemon.blockMove(@pokemon.lastMove)  if @pokemon.lastMove?

class @Attachment.Spikes extends @TeamAttachment
  name: "SpikesAttachment"

  maxLayers: 3

  switchIn: (pokemon) ->
    return  if pokemon.isImmune("Ground")
    fraction = (10 - 2 * @layers)
    hp = pokemon.stat('hp')
    pokemon.damage Math.floor(hp / fraction)
    @battle.message("#{pokemon.name} is hurt by the spikes!")

class @Attachment.StealthRock extends @TeamAttachment
  name: "StealthRockAttachment"

  switchIn: (pokemon) ->
    multiplier = util.typeEffectiveness("Rock", pokemon.types)
    hp = pokemon.stat('hp')
    pokemon.damage Math.floor(hp * multiplier / 8)
    @battle.message("Pointed stones dug into #{pokemon.name}!")

class @Attachment.ToxicSpikes extends @TeamAttachment
  name: "ToxicSpikesAttachment"

  maxLayers: 2

  switchIn: (pokemon) ->
    if pokemon.hasType("Poison") && !pokemon.isImmune("Ground")
      name = @team.player.id
      @battle.message "The poison spikes disappeared from around #{name}'s team's feet!"
      @team.unattach(@constructor)

    return  if pokemon.isImmune("Poison") || pokemon.isImmune("Ground")

    if @layers == 1
      pokemon.attach(Status.Poison)
    else
      pokemon.attach(Status.Toxic)

# A trap created by Fire Spin, Magma Storm, Bind, Clamp, etc
class @Attachment.Trap extends @VolatileAttachment
  name: "TrapAttachment"

  initialize: (attributes) ->
    {@moveName, @user, @turns} = attributes

  beginTurn: ->
    @pokemon.blockSwitch()

  endTurn: ->
    # For the first numTurns turns it will damage, and at numTurns + 1 it will wear off.
    # Therefore, if @turns = 5, this attachment should actually last for 6 turns.
    if @turns == 0
      @battle.message "#{@pokemon.name} was freed from #{@moveName}!"
      @pokemon.unattach(@constructor)
    else
      @battle.message "#{@pokemon.name} is hurt by #{@moveName}!"
      @pokemon.damage Math.floor(@pokemon.stat('hp') / @getDamagePerTurn())
      @turns -= 1

  getDamagePerTurn: ->
    if @user.hasItem("Binding Band")
      8
    else
      16

  unattach: ->
    @user.unattach(Attachment.TrapLeash)
    delete @user

# If the creator if fire spin switches out, the trap will end
# TODO: What happens if another ability removes the trap, and then firespin is used again?
class @Attachment.TrapLeash extends @VolatileAttachment
  name: "TrapLeashAttachment"

  initialize: (attributes) ->
    {@target} = attributes

  unattach: ->
    @target.unattach(Attachment.Trap)
    delete @target

# Has a 50% chance to immobilize a Pokemon before it moves.
class @Attachment.Attract extends @VolatileAttachment
  name: "AttractAttachment"

  initialize: (attributes) ->
    {@source} = attributes
    if @pokemon.hasItem("Destiny Knot") && !@source.has(Attachment.Attract)
      @source.attach(Attachment.Attract, {@source})
      @pokemon.removeItem()

  beforeMove: (move, user, targets) ->
    if @source not in @battle.getOpponents(@pokemon)
      @pokemon.unattach(@constructor)
      return
    if @battle.rng.next('attract chance') < .5
      @battle.message "#{@pokemon.name} is immobilized by love!"
      return false

class @Attachment.FocusEnergy extends @VolatileAttachment
  name: "FocusEnergyAttachment"
  passable: true

class @Attachment.MicleBerry extends @VolatileAttachment
  name: "MicleBerryAttachment"

  initialize: ->
    @turns = 1

  editAccuracy: (accuracy) ->
    Math.floor(accuracy * 1.2)

  endTurn: ->
    if @turns == 0
      @pokemon.unattach(@constructor)
    else
      @turns--

class @Attachment.Metronome extends @VolatileAttachment
  name: "MetronomeAttachment"

  maxLayers: 5

  initialize: (attributes) ->
    {@move} = attributes

  beforeMove: (move) ->
    @pokemon.unattach(@constructor)  if move != @move

class @Attachment.Screen extends @TeamAttachment
  name: "ScreenAttachment"

  initialize: (attributes) ->
    {user} = attributes
    @turns = (if user?.hasItem("Light Clay") then 8 else 5)

  endTurn: ->
    @turns--
    if @turns == 0
      @team.unattach(@constructor)

class @Attachment.Reflect extends @Attachment.Screen
  name: "ReflectAttachment"

  modifyDamageTarget: (move, user) ->
    if move.isPhysical() && !user.crit then 0x800 else 0x1000

class @Attachment.LightScreen extends @Attachment.Screen
  name: "LightScreenAttachment"

  modifyDamageTarget: (move, user) ->
    if move.isSpecial() && !user.crit then 0x800 else 0x1000

class @Attachment.Identify extends @VolatileAttachment
  name: "IdentifyAttachment"

  initialize: (attributes) ->
    {@type} = attributes

  editBoosts: (stages) ->
    stages.evasion = 0
    stages

  isImmune: (type) ->
    return false  if type == @type

class @Attachment.DefenseCurl extends @VolatileAttachment
  name: "DefenseCurl"

class @Attachment.FocusPunch extends @VolatileAttachment
  name: "FocusPunchAttachment"

  beforeMove: (move, user, targets) ->
    hit = user.lastHitBy
    if hit? && !hit.move.isNonDamaging() && hit.turn == @battle.turn
      @battle.message "#{user.name} lost its focus and couldn't move!"
      return false

class @Attachment.MagnetRise extends @VolatileAttachment
  name: "MagnetRiseAttachment"
  passable: true

  initialize: ->
    @turns = 5

  isImmune: (type) ->
    return true  if type == "Ground"

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.LockOn extends @VolatileAttachment
  name: "LockOnAttachment"
  passable: true

  initialize: ->
    @turns = 2

  editAccuracy: ->
    0  # Always hits

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Minimize extends @VolatileAttachment
  name: "MinimizeAttachment"

class @Attachment.MeanLook extends @VolatileAttachment
  name: "MeanLookAttachment"

  beginTurn: ->
    @pokemon.blockSwitch()

class @Attachment.Recharge extends @VolatileAttachment
  name: "RechargeAttachment"

  initialize: ->
    @turns = 2

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.blockMoves()
    {id} = @battle.getOwner(@pokemon)
    @battle.recordMove(id, @battle.getMove("Recharge"))

  beforeMove: (move, user, targets) ->
    @battle.message "#{user.name} must recharge!"
    return false

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Momentum extends @VolatileAttachment
  name: "MomentumAttachment"

  maxLayers: 5

  initialize: (attributes) ->
    {@move} = attributes
    @turns = 1

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.lockMove(@move)

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0 || @layers == @maxLayers

class @Attachment.MeFirst extends @VolatileAttachment
  name: "MeFirstAttachment"

  modifyAttack: ->
    0x1800

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Charge extends @VolatileAttachment
  name: "ChargeAttachment"

  initialize: ->
    @turns = 2

  modifyAttack: (move, target) ->
    return 0x2000  if move.getType(@battle, @pokemon, target) == 'Electric'
    return 0x1000

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.LeechSeed extends @VolatileAttachment
  name: "LeechSeedAttachment"
  passable: true

  initialize: (attributes) ->
    {@slot, @team} = attributes

  endTurn: ->
    user = @team.at(@slot)
    return  if user.isFainted() || @pokemon.isFainted()
    hp = @pokemon.stat('hp')
    damage = Math.min(Math.floor(hp / 8), @pokemon.currentHP)
    @pokemon.damage(damage)
    user.drain(damage, @pokemon)
    @battle.message "#{@pokemon.name}'s health is sapped by Leech Seed!"

class @Attachment.ProtectCounter extends @VolatileAttachment
  name: "ProtectCounterAttachment"

  maxLayers: -1

  successChance: ->
    x = Math.pow(2, @layers - 1)
    if x >= 256 then Math.pow(2, 32) else x

  endTurn: ->
    @turns--
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Protect extends @VolatileAttachment
  name: "ProtectAttachment"

  shouldBlockExecution: (move, user) ->
    if move.hasFlag("protect")
      @battle.message "#{@pokemon.name} protected itself!"
      return true

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Endure extends @VolatileAttachment
  name: "EndureAttachment"

  endTurn: ->
    @pokemon.unattach(@constructor)

  editDamage: (damage, move, user) ->
    if damage >= @pokemon.currentHP
      @battle.message "#{@pokemon.name} endured the hit!"
      return @pokemon.currentHP - 1
    return damage

class @Attachment.Curse extends @VolatileAttachment
  name: "CurseAttachment"
  passable: true

  endTurn: ->
    @pokemon.damage Math.floor(@pokemon.stat('hp') / 4)
    @battle.message "#{@pokemon.name} was afflicted by the curse!"

class @Attachment.DestinyBond extends @VolatileAttachment
  name: "DestinyBondAttachment"

  afterFaint: ->
    pokemon = @battle.lastPokemon
    if pokemon? && pokemon.isAlive()
      pokemon.faint()
      @battle.message "#{pokemon.name} took its attacker down with it!"

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

class @Attachment.Grudge extends @VolatileAttachment
  name: "GrudgeAttachment"

  afterFaint: ->
    hit = @pokemon.lastHitBy
    return  if !hit
    {pokemon, move, turn} = hit
    if pokemon.isAlive() && !move.isNonDamaging()
      pokemon.setPP(move, 0)
      @battle.message "#{pokemon.name}'s #{move.name} lost all its PP due to the grudge!"

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

class @Attachment.Pursuit extends @VolatileAttachment
  name: "PursuitAttachment"

  informSwitch: (switcher) ->
    owner = @battle.getOwner(switcher)
    team = owner.team
    return  if team.has(Attachment.BatonPass)
    pursuit = @battle.getMove('Pursuit')
    @battle.cancelAction(@pokemon)
    @pokemon.attach(Attachment.PursuitModifiers)
    @battle.executeMove(pursuit, @pokemon, [ switcher ])
    @pokemon.unattach(Attachment.PursuitModifiers)
    @pokemon.unattach(@constructor)

  beforeMove: ->
    @pokemon.unattach(@constructor)

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.PursuitModifiers extends @VolatileAttachment
  name: "PursuitModifiersAttachment"

  editAccuracy: ->
    0  # Always hits

class @Attachment.Substitute extends @VolatileAttachment
  name: "SubstituteAttachment"
  passable: true

  initialize: (attributes) ->
    {@hp} = attributes
    @pokemon?.tell(Protocol.POKEMON_ATTACH, @name)

  transformHealthChange: (damage) ->
    @hp -= damage
    if @hp <= 0
      @battle.message "#{@pokemon.name}'s substitute faded!"
      @hp = 0
    else
      @battle.message "The substitute took damage for #{@pokemon.name}!"
    return 0

  shouldBlockExecution: (move, user) ->
    if move.isNonDamaging() && !move.hasFlag('authentic') && @pokemon != user
      move.fail(@battle)
      return true

  afterBeingHit: (move, user, target, damage) ->
    @pokemon.unattach(@constructor)  if @hp <= 0

  unattach: ->
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @name)

class @Attachment.Stockpile extends @VolatileAttachment
  name: "StockpileAttachment"

  maxLayers: 3

class @Attachment.Rage extends @VolatileAttachment
  name: "RageAttachment"

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

  afterBeingHit: (move, user, target, damage) ->
    return  if move.isNonDamaging()
    target.boost(attack: 1)
    @battle.message "#{target.name}'s rage is building!"

class @Attachment.ChipAway extends @VolatileAttachment
  name: "ChipAwayAttachment"

  editBoosts: (stages) ->
    stages.evasion = 0
    stages.defense = 0
    stages.specialDefense = 0
    stages

class @Attachment.AquaRing extends @VolatileAttachment
  name: "AquaRingAttachment"
  passable: true

  endTurn: ->
    amount = Math.floor(@pokemon.stat('hp') / 16)
    # Aqua Ring is considered a drain move for the purposes of Big Root.
    @pokemon.drain(amount, @pokemon)
    @battle.message "Aqua Ring restored #{@pokemon.name}'s HP!"

class @Attachment.Ingrain extends @VolatileAttachment
  name: "IngrainAttachment"
  passable: true

  endTurn: ->
    amount = Math.floor(@pokemon.stat('hp') / 16)
    # Ingrain is considered a drain move for the purposes of Big Root.
    @pokemon.drain(amount, @pokemon)
    @battle.message "#{@pokemon.name} absorbed nutrients with its roots!"

  beginTurn: ->
    @pokemon.blockSwitch()

  shouldPhase: (phaser) ->
    @battle.message "#{@pokemon.name} anchored itself with its roots!"
    return false

  shouldBlockExecution: (move, user) ->
    if move == @battle.getMove("Telekinesis")
      move.fail(@battle)
      return true

  isImmune: (type) ->
    return false  if type == 'Ground'

class @Attachment.Embargo extends @VolatileAttachment
  name: "EmbargoAttachment"
  passable: true

  initialize: ->
    @turns = 5
    @pokemon?.blockItem()

  beginTurn: ->
    @pokemon.blockItem()

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "#{@pokemon.name} can use items again!"
      @pokemon.unattach(@constructor)

class @Attachment.Charging extends @VolatileAttachment
  name: "ChargingAttachment"

  initialize: (attributes) ->
    {@message, @vulnerable, @move, @condition} = attributes
    @charging = false

  beforeMove: (move, user, targets) ->
    if user.hasItem("Power Herb")
      @battle.message "#{user.name} became fully charged due to its Power Herb!"
      @charging = true
      user.removeItem()

    if @charging || @condition?(@battle, move, user, targets)
      @pokemon.unattach(@constructor)
      return

    @charging = true
    @battle.message @message.replace(/$1/g, user.name)
    return false

  beginTurn: ->
    # TODO: Add targets
    {id} = @battle.getOwner(@pokemon)
    @battle.recordMove(id, @move)

  shouldBlockExecution: (move, user) ->
    if @charging && (move not in @vulnerable.map((v) => @battle.getMove(v)))
      @battle.message "#{@pokemon.name} avoided the attack!"
      return true

  unattach: ->
    delete @move
    delete @message
    delete @vulnerable

class @Attachment.FuryCutter extends @VolatileAttachment
  name: "FuryCutterAttachment"

  maxLayers: 3

  initialize: (attributes) ->
    {@move} = attributes

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)  if move != @move

class @Attachment.Imprison extends @VolatileAttachment
  name: "ImprisonAttachment"

  initialize: (attributes) ->
    {@moves} = attributes
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.attach(Attachment.ImprisonPrevention, {@moves})

  beginTurn: ->
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.attach(Attachment.ImprisonPrevention, {@moves})

  switchOut: ->
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.unattach(Attachment.ImprisonPrevention)

class @Attachment.ImprisonPrevention extends @VolatileAttachment
  name: "ImprisonPreventionAttachment"

  initialize: (attributes) ->
    {@moves} = attributes

  beginTurn: ->
    @pokemon.blockMove(move)  for move in @moves

  beforeMove: (move, user, targets) ->
    if move in @moves
      @battle.message "#{user.name} can't use the sealed #{move.name}!"
      return false

class @Attachment.Present extends @VolatileAttachment
  name: "PresentAttachment"

  initialize: (attributes) ->
    {@power} = attributes

  endTurn: ->
    @pokemon.unattach(@constructor)

# Lucky Chant's CH prevention is inside Move#isCriticalHit.
class @Attachment.LuckyChant extends @TeamAttachment
  name: "LuckyChantAttachment"

  initialize: ->
    @turns = 5

  endTurn: ->
    @turns--
    if @turns == 0
      # TODO: Less hacky way of getting id
      {id} = (p for p in @battle.players when p.team == @team)[0]
      @battle.message "#{id}'s team's Lucky Chant wore off!"
      @team.unattach(@constructor)

class @Attachment.LunarDance extends @TeamAttachment
  name: "LunarDanceAttachment"

  switchIn: (pokemon) ->
    @battle.message "#{pokemon.name} became cloaked in mystical moonlight!"
    pokemon.setHP(pokemon.stat('hp'))
    pokemon.cureStatus()
    pokemon.resetAllPP()
    @team.unattach(@constructor)

class @Attachment.HealingWish extends @TeamAttachment
  name: "HealingWishAttachment"

  switchIn: (pokemon) ->
    @battle.message "The healing wish came true for #{pokemon.name}!"
    pokemon.setHP(pokemon.stat('hp'))
    pokemon.cureStatus()
    @team.unattach(@constructor)

class @Attachment.MagicCoat extends @VolatileAttachment
  name: "MagicCoatAttachment"

  initialize: ->
    @bounced = false

  shouldBlockExecution: (move, user) ->
    return  unless move.hasFlag("reflectable")
    return  if user.get(Attachment.MagicCoat)?.bounced
    return  if @bounced
    @bounced = true
    @battle.message "#{@pokemon.name} bounced the #{move.name} back!"
    move.execute(@battle, @pokemon, [ user ])
    return true

  shouldBlockFieldExecution: (move, user) ->
    return  unless move.hasFlag("reflectable")
    return  if @bounced
    for p in user.team.getActiveAlivePokemon()
      return  if p.get(Attachment.MagicCoat)?.bounced
    for p in @team.getActiveAlivePokemon()
      continue  unless p.has(Attachment.MagicCoat)
      @bounced = true
      @battle.message "#{p.name} bounced the #{move.name} back!"
      @battle.executeMove(move, p, [ user ])
      return true

  endTurn: ->
    if @pokemon?
      @pokemon.unattach(@constructor)
    else if @team?
      @team.unattach(@constructor)

class @Attachment.Telekinesis extends @VolatileAttachment
  name: "TelekinesisAttachment"

  initialize: ->
    @turns = 3

  editEvasion: ->
    0  # Always hit

  isImmune: (type) ->
    return true  if type == 'Ground'

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "#{@pokemon} was freed from the telekinesis!"
      @pokemon.unattach(@constructor)

class @Attachment.SmackDown extends @VolatileAttachment
  name: "SmackDownAttachment"

  isImmune: (type) ->
    return false  if type == 'Ground'

  shouldBlockExecution: (move, user) ->
    if move in [ @battle.getMove("Telekinesis"), @battle.getMove("Magnet Rise") ]
      move.fail(@battle)
      return true

class @Attachment.EchoedVoice extends @BattleAttachment
  name: "EchoedVoiceAttachment"

  maxLayers: 4

  initialize: ->
    @turns = 2

  endTurn: ->
    @turns--
    @battle.unattach(@constructor)  if @turns == 0

class @Attachment.Rampage extends @VolatileAttachment
  name: "RampageAttachment"

  maxLayers: -1

  initialize: (attributes) ->
    {@move} = attributes
    @turns = @battle.rng.randInt(2, 3, "rampage turns")
    @turn = 0

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.lockMove(@move)

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.message "#{@pokemon.name} became confused due to fatigue!"
      @pokemon.attach(Attachment.Confusion)
      @pokemon.unattach(@constructor)
    else
      # afterSuccessfulHit increases the number of layers. If the number of
      # layers is not keeping up with the number of turns passed, then the
      # Pokemon's move was interrupted and we should stop rampaging.
      @pokemon.unattach(@constructor)  if @turn > @layers

# The way Trick Room reverses turn order is implemented in Battle#sortActions.
class @Attachment.TrickRoom extends @BattleAttachment
  name: "TrickRoomAttachment"

  initialize: ->
    @turns = 5

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "The twisted dimensions returned to normal!"
      @battle.unattach(@constructor)

class @Attachment.Transform extends @VolatileAttachment
  name: "TransformAttachment"

  @preattach: (attributes) ->
    {target} = attributes
    !target.has(Attachment.Transform)

  initialize: (attributes) ->
    {target} = attributes
    # Save old data
    {@ability, @species, @moves, @stages, @types, @gender, @weight} = @pokemon
    {@ppHash, @maxPPHash} = @pokemon
    # This data is safe to be copied.
    @pokemon.copyAbility(target.ability)
    @pokemon.species = target.species
    @pokemon.gender  = target.gender
    @pokemon.weight  = target.weight
    # The rest aren't.
    @pokemon.moves   = _.clone(target.moves)
    @pokemon.stages  = _.clone(target.stages)
    @pokemon.types   = _.clone(target.types)
    @pokemon.resetAllPP(5)

  unattach: ->
    # Restore old data
    @pokemon.ability   = @ability
    @pokemon.species   = @species
    @pokemon.moves     = @moves
    @pokemon.stages    = @stages
    @pokemon.types     = @types
    @pokemon.gender    = @gender
    @pokemon.weight    = @weight
    @pokemon.ppHash    = @ppHash
    @pokemon.maxPPHash = @maxPPHash

class @Attachment.Fling extends @VolatileAttachment
  name: "FlingAttachment"

  initialize: ->
    @item = null

  beforeMove: (move, user, targets) ->
    # The move may be changed by something like Encore
    return  if move != @battle.getMove("Fling")
    if user.hasItem() && user.hasTakeableItem() && !user.isItemBlocked()
      @item = user.getItem()
      user.removeItem()

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.BeatUp extends @VolatileAttachment
  name: "BeatUpAttachment"

  initialize: ->
    @index = -1

class @Attachment.Gravity extends @BattleAttachment
  name: "GravityAttachment"

  initialize: ->
    @turns = 5

  beginTurn: ->
    for pokemon in @battle.getActivePokemon()
      pokemon.attach(Attachment.GravityPokemon)
      for move in pokemon.moves
        pokemon.blockMove(move)  if move.hasFlag("gravity")

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "Gravity turned to normal!"
      @battle.unattach(@constructor)

class @Attachment.GravityPokemon extends @VolatileAttachment
  name: "GravityPokemonAttachment"

  beforeMove: (move, user, target) ->
    if move.hasFlag("gravity")
      @battle.message "#{user.name} can't use #{move.name} because of gravity!"
      return false

  editAccuracy: (accuracy) ->
    Math.floor(accuracy * 5 / 3)

  isImmune: (type) ->
    # TODO: Display "POKEMON couldn't stay airborne because of gravity!"?
    return false  if type == 'Ground'

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.DelayedAttack extends @TeamAttachment
  name: "DelayedAttackAttachment"

  initialize: (attributes) ->
    {@move, @user} = attributes
    @slot = 0
    @turns = 3

  endTurn: ->
    @turns--
    if @turns == 0
      pokemon = @team.at(@slot)
      if pokemon.isAlive()
        @battle.message "#{pokemon.name} took the #{@move.name} attack!"
        @move.hit(@battle, @user, pokemon)
      @team.unattach(@constructor)

class @Attachment.BatonPass extends @TeamAttachment
  name: "BatonPassAttachment"

  initialize: (attributes) ->
    {@slot, @attachments, @stages} = attributes

  switchIn: (pokemon) ->
    return  if @slot != @team.indexOf(pokemon)
    # Nasty stitching of attachments to the recipient.
    for attachment in @attachments
      attachment.pokemon = pokemon
      attachment.team = pokemon.team
      attachment.battle = pokemon.battle
      attachment.attached = true
      pokemon.attachments.attachments.push(attachment)
    pokemon.boost(@stages)
    @team.unattach(@constructor)

class @Attachment.FlashFire extends @VolatileAttachment
  name: "FlashFireAttachment"

  modifyBasePower: (move, user, target) ->
    return 0x1000  if move.getType(@battle, @pokemon, target) != 'Fire'
    return 0x1800

class @Attachment.Unburden extends @VolatileAttachment
  name: "UnburdenAttachment"

  editSpeed: (speed) ->
    2 * speed

class @StatusAttachment extends @BaseAttachment
  name: "StatusAttachment"

  @preattach: (options, attributes) ->
    {battle, pokemon} = attributes
    {source, force} = options
    force ?= false
    if !force
      return false  if pokemon.hasStatus()
      return false  if battle?.hasWeather(Weather.SUN) && pokemon.hasAbility("Leaf Guard")
      return false  if this == Status.Burn && pokemon.hasType("Fire")
      return false  if this == Status.Toxic && pokemon.hasType("Poison")
      return false  if this == Status.Poison && pokemon.hasType("Poison")
      return false  if this == Status.Freeze &&
        (pokemon.hasType("Ice") || battle?.hasWeather(Weather.SUN))
      if source && pokemon.hasAbility("Synchronize")
        return false  if source == pokemon
        source.attach(this)  # Do not attach source
        battle.message "#{pokemon.name} synchronized its status with #{source.name}!"
    else
      pokemon.cureStatus()
    pokemon.status = @name
    return true

  initialize: ->
    wasStatused = switch @constructor
      when Status.Paralyze
        "was paralyzed"
      when Status.Freeze
        "was frozen"
      when Status.Poison
        "was poisoned"
      when Status.Toxic
        "was badly poisoned"
      when Status.Sleep
        "fell asleep"
      when Status.Burn
        "was burned"
    @battle?.message "#{@pokemon.name} #{wasStatused}!"
    @pokemon.tell(Protocol.POKEMON_ATTACH, @name)

  unattach: ->
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @name)
    @pokemon.status = null

class @Status.Paralyze extends @StatusAttachment
  name: "Paralyze"

  beforeMove: (move, user, targets) ->
    if @battle.rng.next('paralyze chance') < .25
      @battle.message "#{@pokemon.name} is fully paralyzed!"
      return false

  editSpeed: (stat) ->
    if @pokemon.hasAbility("Quick Feet") then stat else stat >> 2

class @Status.Freeze extends @StatusAttachment
  name: "Freeze"

  beforeMove: (move, user, targets) ->
    if move.thawsUser || @battle.rng.next('unfreeze chance') < .2
      @battle.message "#{@pokemon.name} thawed out!"
      @pokemon.cureStatus()
    else
      @battle.message "#{@pokemon.name} is frozen solid!"
      return false

  afterBeingHit: (move, user, target, damage) ->
    if !move.isNonDamaging() && move.type == 'Fire'
      @battle.message "#{@pokemon.name} thawed out!"
      @pokemon.cureStatus()

class @Status.Poison extends @StatusAttachment
  name: "Poison"

  endTurn: ->
    return  if @pokemon.hasAbility("Poison Heal")
    @battle.message "#{@pokemon.name} was hurt by poison!"
    @pokemon.damage(@pokemon.stat('hp') >> 3)

class @Status.Toxic extends @StatusAttachment
  name: "Toxic"

  initialize: ->
    super()
    @counter = 0

  switchOut: ->
    @counter = 0

  endTurn: ->
    return  if @pokemon.hasAbility("Poison Heal")
    @battle.message "#{@pokemon.name} was hurt by poison!"
    @counter = Math.min(@counter + 1, 15)
    @pokemon.damage Math.floor(@pokemon.stat('hp') * @counter / 16)

class @Status.Sleep extends @StatusAttachment
  name: "Sleep"

  initialize: (attributes) ->
    super()
    @counter = 0
    {@turns} = attributes
    if !@turns && @battle?
      @turns = @battle.rng.randInt(1, 3, "sleep turns")
      @turns >>= 1  if @pokemon.hasAbility("Early Bird")

  switchOut: ->
    @counter = 0

  beforeMove: (move, user, targets) ->
    if @counter == @turns
      @battle.message "#{@pokemon.name} woke up!"
      @pokemon.cureStatus()
    else
      @battle.message "#{@pokemon.name} is fast asleep."
      @counter += 1
      return false  unless move.usableWhileAsleep

class @Status.Burn extends @StatusAttachment
  name: "Burn"

  endTurn: ->
    @battle.message "#{@pokemon.name} was hurt by its burn!"
    @pokemon.damage(@pokemon.stat('hp') >> 3)
