{Attachment, VolatileAttachment} = require '../../server/attachment'
{Status} = require '../../server/status'
{Weather} = require '../../server/weather'
util = require '../../server/util'
require 'sugar'

@Ability = Ability = {}

makeAbility = (name, func) ->
  condensed = name.replace(/\s+/g, '')
  class Ability[condensed] extends VolatileAttachment
    name: name
    func?.call(this)

makeAbility 'Technician'
makeAbility 'Natural Cure'
makeAbility 'Guts'
makeAbility 'Flare Boost'
makeAbility 'Reckless'
makeAbility 'Iron Fist'
makeAbility 'Toxic Boost'
makeAbility 'Rivalry'
makeAbility 'Sand Force'
makeAbility 'Heatproof'
makeAbility 'Dry Skin'
makeAbility 'Sheer Force'

# TODO: Add hook to CH level.
makeAbility 'Super Luck'
makeAbility 'Battle Armor'
makeAbility 'Shell Armor'

makeAbility 'Tinted Lens'
makeAbility 'Sniper'

makeAbility 'Sticky Hold'
makeAbility 'Multitype'

makeAbility "Skill Link"

# Ability templates

makeWeatherPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsWeather = true

    this::switchIn = (battle) ->
      battle.message "The effects of weather disappeared."

makeWeatherPreventionAbility("Air Lock")
makeWeatherPreventionAbility("Cloud Nine")

makeCriticalHitPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsCriticalHits = true

makeCriticalHitPreventionAbility("Battle Armor")
makeCriticalHitPreventionAbility("Shell Armor")

makeWeatherSpeedAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = (battle) ->
      @doubleSpeed = battle.hasWeather(weather)

    this::informWeather = (newWeather) ->
      @doubleSpeed = (weather == newWeather)

    this::modifySpeed = (speed) ->
      if @doubleSpeed then 2 * speed else speed

makeWeatherSpeedAbility("Chlorophyll", Weather.SUN)
makeWeatherSpeedAbility("Swift Swim", Weather.RAIN)
makeWeatherSpeedAbility("Sand Rush", Weather.SAND)

makeLowHealthAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (battle, move, user, target) ->
      return 0x1000  if move.getType(battle, user, target) != type
      return 0x1000  if user.currentHP > Math.floor(user.stat('hp') / 3)
      return 0x1800

makeLowHealthAbility("Blaze", "Fire")
makeLowHealthAbility("Torrent", "Water")
makeLowHealthAbility("Overgrow", "Grass")
makeLowHealthAbility("Swarm", "Bug")

makeWeatherAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = (battle) ->
      battle.setWeather(weather)

makeWeatherAbility("Drizzle", Weather.RAIN)
makeWeatherAbility("Drought", Weather.SUN)
makeWeatherAbility("Sand Stream", Weather.SAND)
makeWeatherAbility("Snow Warning", Weather.HAIL)

makeFilterAbility = (name) ->
  makeAbility name, ->
    this::modifyDamageTarget = (battle, move, user) ->
      if util.typeEffectiveness(move.type, user.types) > 1
        0xC00
      else
        0x1000

makeFilterAbility("Filter")
makeFilterAbility("Solid Rock")

makeContactStatusAbility = (name, statusOrAttachment) ->
  isStatus = (statusOrAttachment in Object.values(Status))
  attachFunc = (if isStatus then "setStatus" else "attach")
  makeAbility name, ->
    this::afterBeingHit = (battle, move, user) ->
      return  if !move.hasFlag("contact")
      return  if battle.rng.next("contact status") >= .3
      user[attachFunc](statusOrAttachment, source: @pokemon)

makeContactStatusAbility("Cute Charm", Attachment.Attract)
makeContactStatusAbility("Flame Body", Status.BURN)
makeContactStatusAbility("Poison Point", Status.POISON)
makeContactStatusAbility("Static", Status.PARALYZE)

makeStatusBoostAbility = (name, statuses, spectra) ->
  makeAbility name, ->
    this::modifyBasePower = (battle, move, user, target) ->
      if move.spectra == spectra && @pokemon.hasStatus(statuses...)
        0x1800
      else
        0x1000

makeStatusBoostAbility("Flare Boost", [Status.BURN], 'special')
makeStatusBoostAbility("Toxic Boost", [Status.POISON, Status.TOXIC], 'physical')

# Unique Abilities

makeAbility "Adaptability"

makeAbility "Aftermath", ->
  this::afterFaint = (battle) ->
    {pokemon, damage, move, turn} = @pokemon.lastHitBy
    if move.hasFlag('contact')
      pokemon.damage(pokemon.stat('hp') >> 2)
      battle.message "The #{@pokemon.name}'s Aftermath dealt damage to #{pokemon.name}!"

makeAbility 'Analytic', ->
  this::modifyBasePower = (battle, mmove, user, target) ->
    if !battle.hasActionsLeft() then 0x14CD else 0x1000

makeAbility "Anger Point", ->
  this::informCriticalHit = (battle) ->
    battle.message "#{@pokemon.name} maxed its Attack!"
    @pokemon.boost(attack: 12)

makeAbility "Anticipation", ->
  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    moves = (opponent.moves  for opponent in opponents).flatten()
    for move in moves
      effectiveness = util.typeEffectiveness(move.type, @pokemon.types) > 1
      if effectiveness || move.hasFlag("ohko")
        battle.message "#{@pokemon.name} shuddered!"
        break

makeAbility "Arena Trap", ->
  this::beginTurn = this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    for opponent in opponents
      opponent.blockSwitch()  unless opponent.isImmune(battle, "Ground")

makeAbility "Bad Dreams", ->
  this::endTurn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    for opponent in opponents
      continue  unless opponent.hasStatus(Status.SLEEP)
      battle.message "#{opponent.name} is tormented!"
      amount = opponent.stat('hp') >> 3
      opponent.damage(amount)

makeAbility "Color Change", ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    {type} = move
    if !move.isNonDamaging() && !target.hasType(type)
      battle.message "#{target.name}'s Color Change made it the #{type} type!"
      target.types = [ type ]

makeAbility "Compoundeyes", ->
  this::editAccuracy = (accuracy) ->
    Math.floor(1.3 * accuracy)

# Hardcoded in Pokemon#boost
makeAbility "Contrary"

makeAbility "Cursed Body", ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    return  if user.has(Attachment.Substitute)
    return  if battle.rng.next("cursed body") >= .3
    battle.message "#{user.name}'s #{move.name} was disabled!"
    user.blockMove(move)

# Implementation is done in moves.coffee, specifically makeExplosionMove.
makeAbility 'Damp'

makeAbility 'Defeatist', ->
  this::modifyAttack = (attack) ->
    halfHP = (@pokemon.stat('hp') >> 1)
    if @pokemon.currentHP <= halfHP then attack >> 1 else attack

  this::modifySpecialAttack = (specialAttack) ->
    halfHP = (@pokemon.stat('hp') >> 1)
    if @pokemon.currentHP <= halfHP then specialAttack >> 1 else specialAttack

makeAbility 'Download', ->
  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    totalDef = opponents.reduce(((s, p) -> s + p.stat('defense')), 0)
    totalSpDef = opponents.reduce(((s, p) -> s + p.stat('specialDefense')), 0)
    # TODO: Real message
    if totalSpDef <= totalDef
      @pokemon.boost(specialAttack: 1)
      battle.message "#{@pokemon.name}'s Download boosted its Special Attack!"
    else
      @pokemon.boost(attack: 1)
      battle.message "#{@pokemon.name}'s Download boosted its Attack!"

makeAbility 'Dry Skin', ->
  this::modifyBasePowerTarget = (battle, move, user, target) ->
    if move.getType(battle, user, target) == 'Fire' then 0x1400 else 0x1000

  this::endTurn = (battle) ->
    # TODO: Real message
    if battle.hasWeather(Weather.SUN)
      @pokemon.damage(@pokemon.stat('hp') >> 3)
      battle.message "#{@pokemon.name}'s Dry Skin hurts under the sun!"
    else if battle.hasWeather(Weather.RAIN)
      @pokemon.damage(-(@pokemon.stat('hp') >> 3))
      battle.message "#{@pokemon.name}'s Dry Skin restored its HP a little!"

  this::shouldBlockExecution = (battle, move, user) ->
    return  if move.getType(battle, user, @pokemon) != 'Water'
    @pokemon.damage(-(@pokemon.stat('hp') >> 2))
    battle.message "#{@pokemon.name}'s Dry Skin restored its HP a little!"
    return true

# Implementation is in Attachment.Sleep
makeAbility 'Early Bird'

makeAbility 'Effect Spore', ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    return  unless move.hasFlag("contact")
    switch battle.rng.randInt(1, 10, "effect spore")
      when 1
        user.setStatus(Status.SLEEP)
        battle.message "#{user.name} fell asleep!"
      when 2
        user.setStatus(Status.PARALYZE)
        battle.message "#{user.name} was paralyzed!"
      when 3
        user.setStatus(Status.POISON)
        battle.message "#{user.name} was poisoned!"

makeAbility 'Flash Fire', ->
  this::shouldBlockExecution = (battle, move, user) ->
    return  if move.getType(battle, user, @pokemon) != 'Fire'
    battle.message "The power of #{@pokemon.name}'s Fire-type moves rose!"
    @pokemon.attach(Attachment.FlashFire)
    return true

makeAbility 'Forewarn', ->
  VariablePowerMoves =
    'crush-grip'   : true
    'dragon-rage'  : true
    'endeavor'     : true
    'flail'        : true
    'frustration'  : true 
    'grass-knot'   : true
    'gyro-ball'    : true
    'sonicboom'    : true
    'hidden-power' : true
    'low-kick'     : true
    'natural-gift' : true
    'night-shade'  : true
    'psywave'      : true
    'return'       : true
    'reversal'     : true
    'seismic-toss' : true
    'trump-card'   : true
    'wring-out'    : true

  CounterMoves =
    "counter"     : true
    "mirror-coat" : true
    "metal-burst" : true

  @consider = consider = (move) ->
    if move.hasFlag('ohko')
      160
    else if CounterMoves[move.name]
      120
    else if VariablePowerMoves[move.name]
      80
    else
      move.power

  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    moves = (opponent.moves  for opponent in opponents).flatten()
    maxPower = Math.max(moves.map((m) -> consider(m))...)
    possibles = moves.filter((m) -> consider(m) == maxPower)
    finalMove = battle.rng.choice(possibles, "forewarn")
    owner = opponents.find((p) -> finalMove in p.moves)
    battle.message "It was alerted to #{owner.name}'s #{finalMove.name}!"

makeAbility "Frisk", ->
  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    # TODO: Do you select from opponents with items, or all alive opponents?
    opponent  = battle.rng.choice(opponents, "frisk")
    if opponent.hasItem()
      item = opponent.getItem()
      battle.message "#{@pokemon.name} frisked its target and found one #{item.name}!"
