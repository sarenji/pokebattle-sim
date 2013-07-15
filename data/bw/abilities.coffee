{Attachment, VolatileAttachment} = require '../../server/attachment'
{Status} = require '../../server/status'
{Weather} = require '../../server/weather'
util = require '../../server/util'
require 'sugar'

@Ability = Ability = {}

makeAbility = (name, extension, func) ->
  if arguments.length < 3
    [extension, func] = [VolatileAttachment, extension]
  condensed = name.replace(/\s+/g, '')
  class Ability[condensed] extends extension
    name: name
    func?.call(this)

makeAbility 'Reckless'
makeAbility 'Sheer Force'
makeAbility 'Sniper'

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

    this::editSpeed = (speed) ->
      if @doubleSpeed then 2 * speed else speed

    this::isWeatherDamageImmune = (battle, currentWeather) ->
      return true  if weather == currentWeather

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

makeContactStatusAbility = (name, attachment) ->
  makeAbility name, ->
    this::afterBeingHit = (battle, move, user) ->
      return  if !move.hasFlag("contact")
      return  if battle.rng.next("contact status") >= .3
      user.attach(attachment, source: @pokemon)

makeContactStatusAbility("Cute Charm", Attachment.Attract)
makeContactStatusAbility("Flame Body", Status.Burn)
makeContactStatusAbility("Poison Point", Status.Poison)
makeContactStatusAbility("Static", Status.Paralyze)

makeStatusBoostAbility = (name, statuses, spectra) ->
  makeAbility name, ->
    this::modifyBasePower = (battle, move, user, target) ->
      if move.spectra == spectra && statuses.some((s) => @pokemon.has(s))
        0x1800
      else
        0x1000

makeStatusBoostAbility("Flare Boost", [Status.Burn], 'special')
makeStatusBoostAbility("Toxic Boost", [Status.Poison, Status.Toxic], 'physical')

makeHugePowerAbility = (name) ->
  makeAbility name, ->
    this::modifyAttack = (battle, move) ->
      if move.isPhysical() then 0x2000 else 0x1000

makeHugePowerAbility("Huge Power")
makeHugePowerAbility("Pure Power")

makeAttachmentImmuneAbility = (name, immuneAttachments) ->
  makeAbility name, ->
    this::shouldAttach = (attachment) ->
      # TODO: Message that you're immune
      return attachment not in immuneAttachments

    this::update = (battle) ->
      for attachment in immuneAttachments
        if @pokemon.unattach(attachment)
          # TODO: end message
          battle.message "#{@pokemon.name} no longer has #{attachment.name}."

makeAttachmentImmuneAbility("Immunity", [Status.Poison, Status.Toxic])
makeAttachmentImmuneAbility("Inner Focus", [Attachment.Flinch])
makeAttachmentImmuneAbility("Insomnia", [Status.Sleep])
makeAttachmentImmuneAbility("Limber", [Status.Paralyze])
makeAttachmentImmuneAbility("Magma Armor", [Status.Freeze])
makeAttachmentImmuneAbility("Oblivious", [Attachment.Attract])
makeAttachmentImmuneAbility("Own Tempo", [Attachment.Confusion])
makeAttachmentImmuneAbility("Vital Spirit", [Status.Sleep])
makeAttachmentImmuneAbility("Water Veil", [Status.Burn])

makeContactHurtAbility = (name) ->
  makeAbility name, ->
    this::afterBeingHit = (battle, move, user, target, damage) ->
      return  unless move.hasFlag('contact')
      battle.message "#{user.name} was hurt!"
      amount = user.stat('hp') >> 3
      user.damage(amount)

makeContactHurtAbility("Iron Barbs")
makeContactHurtAbility("Rough Skin")

makeRedirectAndBoostAbility = (name, type) ->
  makeAbility name, ->
    # TODO: This should be implemented as isImmune instead.
    # TODO: Type-immunities should come before ability immunities.
    this::shouldBlockExecution = (battle, move, user) ->
      return  if move.getType(battle, user, @pokemon) != type
      @pokemon.boost(specialAttack: 1)  unless @pokemon.isImmune(battle, type)
      return true

makeRedirectAndBoostAbility("Lightningrod", "Electric")
makeRedirectAndBoostAbility("Storm Drain", "Water")

makeTypeImmuneAbility = (name, type, stat) ->
  makeAbility name, ->
    this::shouldBlockExecution = (battle, move, user) ->
      return  if move.getType(battle, user, @pokemon) != type
      battle.message "#{@pokemon.name}'s #{name} increased its #{stat}!"
      hash = {}
      hash[stat] = 1
      @pokemon.boost(hash)
      return true

makeTypeImmuneAbility("Motor Drive", "Electric", "speed")
makeTypeImmuneAbility("Sap Sipper", "Grass", "attack")

makeTypeAbsorbMove = (name, type) ->
  makeAbility name, ->
    this::shouldBlockExecution = (battle, move, user) ->
      return  if move.getType(battle, user, @pokemon) != type
      battle.message "#{@pokemon.name} restored its HP a little."
      amount = @pokemon.stat('hp') >> 2
      @pokemon.damage(-amount)

makeTypeAbsorbMove("Water Absorb", "Water")
makeTypeAbsorbMove("Volt Absorb", "Electric")

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
      continue  unless opponent.has(Status.Sleep)
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
  this::modifyAttack = (battle, move, target) ->
    halfHP = (@pokemon.stat('hp') >> 1)
    if @pokemon.currentHP <= halfHP then 0x800 else 0x1000

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
  this::modifyBasePowerTarget = (battle, move, user) ->
    if move.getType(battle, user, @pokemon) == 'Fire' then 0x1400 else 0x1000

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
        if user.attach(Status.Sleep)
          battle.message "#{user.name} fell asleep!"
      when 2
        if user.attach(Status.Paralyze)
          battle.message "#{user.name} was paralyzed!"
      when 3
        if user.attach(Status.Poison)
          battle.message "#{user.name} was poisoned!"

makeAbility 'Flash Fire', ->
  this::shouldBlockExecution = (battle, move, user) ->
    return  if move.getType(battle, user, @pokemon) != 'Fire'
    battle.message "The power of #{@pokemon.name}'s Fire-type moves rose!"
    @pokemon.attach(Attachment.FlashFire)
    return true

makeAbility 'Forecast'

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

# Implemented in items.coffee; makePinchBerry
makeAbility "Gluttony"

makeAbility "Guts", ->
  this::modifyAttack = (battle, move, target) ->
    return 0x1800  if @pokemon.hasStatus() && move.isPhysical()
    return 0x1000

makeAbility 'Harvest', ->
  this::endTurn = (battle) ->
    return  unless @pokemon.lastItem?.type == 'berries'
    shouldHarvest = battle.hasWeather(Weather.SUN)
    shouldHarvest ||= battle.rng.randInt(0, 1, "harvest") == 1
    if shouldHarvest
      battle.message "#{@pokemon.name} harvested one #{@pokemon.lastItem.name}!"
      @pokemon.setItem(battle, @pokemon.lastItem)

makeAbility 'Heatproof', ->
  this::modifyBasePowerTarget = (battle, move, user) ->
    return 0x800  if move.getType(battle, user, @pokemon) == 'Fire'
    return 0x1000

makeAbility 'Hustle', ->
  this::modifyAttack = (battle, move, target) ->
    return 0x1800  if move.isPhysical()
    return 0x1000

  this::editAccuracy = (accuracy, move) ->
    return Math.floor(0.8 * accuracy)  if move.isPhysical()
    return accuracy

makeAbility "Hydration", ->
  this::endTurn = (battle) ->
    if battle.hasWeather(Weather.RAIN) && @pokemon.hasStatus()
      battle.message "#{@pokemon.name} was cured of its #{@pokemon.status}!"
      @pokemon.cureStatus()

makeAbility 'Ice Body', ->
  this::endTurn = (battle) ->
    if battle.hasWeather(Weather.HAIL)
      battle.message "#{@pokemon.name}'s Ice Body restored its HP a little."
      amount = @pokemon.stat('hp') >> 4
      @pokemon.damage(-amount)

  this::isWeatherDamageImmune = (battle, weather) ->
    return true  if weather == Weather.HAIL

makeAbility 'Iron Fist', ->
  this::modifyBasePower = (battle, move) ->
    if move.hasFlag('punch') then 0x1333 else 0x1000

makeAbility 'Justified', ->
  this::afterBeingHit = (battle, move, user) ->
    if move.getType(battle, user, @pokemon) == 'Dark'
      @pokemon.boost(attack: 1)
      # TODO: Message
      battle.message "#{@pokemon.name}'s attack rose!"

makeAbility 'Klutz', ->
  this::beginTurn = this::switchIn = ->
    @pokemon.blockItem()

makeAbility 'Levitate', ->
  this::isImmune = (battle, type) ->
    return true  if type == 'Ground'

# Implemented in Pokemon#drain
makeAbility 'Liquid Ooze'

makeAbility 'Magic Bounce', Attachment.MagicCoat, ->
  this::beginTurn = ->
    @bounced = false

  this::endTurn = ->

makeAbility 'Magnet Pull', ->
  this::beginTurn = this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    opponents = opponents.filter((p) -> p.hasType("Steel"))
    opponent.blockSwitch()  for opponent in opponents

makeAbility 'Multiscale', ->
  this::modifyDamageTarget = ->
    return 0x800  if @pokemon.currentHP == @pokemon.stat('hp')
    return 0x1000

makeAbility 'Multitype'

makeAbility 'Natural Cure', ->
  this::switchOut = ->
    @pokemon.cureStatus()

makeAbility 'No Guard', ->
  this::editAccuracy = -> 0  # Never miss
  this::editEvasion  = -> 0  # Never miss

makeAbility 'Overcoat', ->
  this::isWeatherDamageImmune = -> true

makeAbility 'Poison Heal', ->
  # Poison damage neutralization is hardcoded in Attachment.Poison and Toxic.
  this::endTurn = ->
    if @pokemon.has(Status.Poison) || @pokemon.has(Status.Toxic)
      amount = @pokemon.stat('hp') >> 3
      @pokemon.damage(-amount)

# Hardcoded in Battle#actionPriority
makeAbility 'Prankster'

# PP deduction hardcoded in Battle
makeAbility 'Pressure', ->
  this::switchIn = (battle) ->
    battle.message "#{@pokemon.name} is exerting its pressure!"

# Speed drop negation hardcoded into Attachment.Paralyze
makeAbility 'Quick Feet', ->
  this::editSpeed = (speed) ->
    if @pokemon.hasStatus() then Math.floor(1.5 * speed) else speed

makeAbility 'Rain Dish', ->
  this::endTurn = (battle) ->
    return  unless battle.hasWeather(Weather.RAIN)
    battle.message "#{@pokemon.name}'s Rain Dish restored its HP a little."
    amount = @pokemon.stat('hp') >> 4
    @pokemon.damage(-amount)

makeAbility 'Rivalry', ->
  this::modifyBasePower = (battle, move, user, target) ->
    return 0x1400  if user.gender == target.gender
    return 0xC00   if (user.gender == 'F' && target.gender == 'M') ||
                      (user.gender == 'M' && target.gender == 'F')
    return 0x1000

makeAbility 'Regenerator', ->
  this::switchOut = ->
    amount = util.roundHalfDown(@pokemon.stat('hp') / 3)
    @pokemon.damage(-amount)

makeAbility 'Sand Force', ->
  this::modifyBasePower = (battle, move, user) ->
    type = move.getType(battle, user, @pokemon)
    return 0x14CD  if type in ['Rock', 'Ground', 'Steel']
    return 0x1000

  this::isWeatherDamageImmune = (battle, weather) ->
    return true  if weather == Weather.SAND

makeAbility 'Shadow Tag', ->
  this::beginTurn = this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    for opponent in opponents
      opponent.blockSwitch()

# Implementation hardcoded in Move#calculateNumberOfHits.
# Tested in test/bw/moves.coffee.
makeAbility "Skill Link"

makeAbility 'Soundproof', ->
  this::isImmune = (battle, type, move) ->
    return true  if move?.hasFlag('sound')

makeAbility 'Speed Boost', ->
  this::endTurn = (battle) ->
    return  if @pokemon.turnsActive <= 0
    boosts = {speed: 1}
    boostedStats = @pokemon.boost(boosts)
    util.printBoostMessage(battle, @pokemon, boostedStats, boosts)

# Hardcoded in Pokemon#hasTakeableItem
makeAbility 'Sticky Hold'

makeAbility 'Sturdy', ->
  this::editDamage = (damage, battle, move) ->
    if @pokemon.currentHP == @pokemon.stat('hp')
      if damage >= @pokemon.currentHP
        battle.message "#{@pokemon.name} endured the hit!"
        return @pokemon.currentHP - 1
    return damage

makeAbility 'Suction Cups', ->
  this::shouldPhase = (battle, phaser) ->
    battle.message "#{@pokemon.name} anchors itself!"
    return false

# Hardcoded in Move#criticalHitLevel
makeAbility 'Super Luck'

makeAbility 'Tangled Feet', ->
  this::editEvasion = (evasion) ->
    if @pokemon.has(Attachment.Confusion) then evasion >> 1 else evasion

makeAbility 'Technician', ->
  this::modifyBasePower = (battle, move, user) ->
    return 0x1800  if move.basePower(battle, user, @pokemon) <= 60
    return 0x1000

makeAbility 'Thick Fat', ->
  this::modifyAttackTarget = (battle, move, user) ->
    return 0x800  if move.getType(battle, user, @pokemon) in [ 'Fire', 'Ice' ]
    return 0x1000

makeAbility 'Tinted Lens', ->
  this::modifyDamage = (battle, move, target) ->
    return 0x2000  if move.typeEffectiveness(battle, @pokemon, target) < 1
    return 0x1000

makeAbility 'Trace', ->
  bannedAbilities =
    "Flower Gift" : true
    "Forecast"    : true
    "Illusion"    : true
    "Imposter"    : true
    "Multitype"   : true
    "Trace"       : true
    "Zen Mode"    : true

  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    abilities = (opponent.ability  for opponent in opponents).compact()
    ability   = battle.rng.choice(abilities, "trace")
    if ability && ability::name not of bannedAbilities
      @pokemon.copyAbility(battle, ability)

makeAbility 'Truant', ->
  this::initialize = ->
    @truanted = true

  this::beforeMove = (battle) ->
    @truanted = !@truanted
    if @truanted
      battle.message "#{@pokemon.name} is loafing around!"
      return false

# Hardcoded in Pokemon#removeItem
makeAbility 'Unburden'

makeAbility 'Victory Star', ->
  this::editAccuracy = (accuracy) ->
    Math.floor(accuracy * 1.1)
