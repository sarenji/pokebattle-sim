{_} = require 'underscore'
{Attachment, Status, VolatileAttachment} = require '../attachment'
{Weather} = require '../../../shared/weather'
util = require '../util'

@Ability = Ability = {}

makeAbility = (name, func) ->
  condensed = name.replace(/\s+/g, '')
  class Ability[condensed] extends VolatileAttachment
    @displayName: name
    displayName: name
    ability: true
    func?.call(this)

# TODO: Implement.
makeAbility 'Pickup'

# Ability templates

makeWeatherPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsWeather = true

    this::switchIn = ->
      @pokemon.activateAbility()
      @battle.cannedText('WEATHER_DISABLED')

makeWeatherPreventionAbility("Air Lock")
makeWeatherPreventionAbility("Cloud Nine")

makeCriticalHitPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsCriticalHits = true

makeCriticalHitPreventionAbility("Battle Armor")
makeCriticalHitPreventionAbility("Shell Armor")

makeBoostProtectionAbility = (name, protection) ->
  makeAbility name, ->
    this::transformBoosts = (boosts, source) ->
      return boosts  if source == @pokemon
      didProtect = false
      for stat of boosts
        if (!protection || stat in protection) && boosts[stat] < 0
          didProtect = true
          boosts[stat] = 0
      @pokemon.activateAbility()  if didProtect
      boosts

makeBoostProtectionAbility("Big Pecks", [ "defense" ])
makeBoostProtectionAbility("Clear Body")
makeBoostProtectionAbility("Hyper Cutter", [ "attack" ])
makeBoostProtectionAbility("Keen Eye", [ "accuracy" ])
makeBoostProtectionAbility("White Smoke")

makeWeatherSpeedAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = ->
      @doubleSpeed = @battle.hasWeather(weather)

    this::informWeather = (newWeather) ->
      @doubleSpeed = (weather == newWeather)

    this::editSpeed = (speed) ->
      if @doubleSpeed then 2 * speed else speed

    this::isWeatherDamageImmune = (currentWeather) ->
      return true  if weather == currentWeather

makeWeatherSpeedAbility("Chlorophyll", Weather.SUN)
makeWeatherSpeedAbility("Swift Swim", Weather.RAIN)
makeWeatherSpeedAbility("Sand Rush", Weather.SAND)

makeLowHealthAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (move, target) ->
      return 0x1000  if move.getType(@battle, @pokemon, target) != type
      return 0x1000  if @pokemon.currentHP > Math.floor(@pokemon.stat('hp') / 3)
      return 0x1800

makeLowHealthAbility("Blaze", "Fire")
makeLowHealthAbility("Torrent", "Water")
makeLowHealthAbility("Overgrow", "Grass")
makeLowHealthAbility("Swarm", "Bug")

makeWeatherAbility = makeWeatherAbility ? (name, weather) ->
  makeAbility name, ->
    this::switchIn = ->
      @pokemon.activateAbility()
      @battle.setWeather(weather)

makeWeatherAbility("Drizzle", Weather.RAIN)
makeWeatherAbility("Drought", Weather.SUN)
makeWeatherAbility("Sand Stream", Weather.SAND)
makeWeatherAbility("Snow Warning", Weather.HAIL)

makeFilterAbility = (name) ->
  makeAbility name, ->
    this::modifyDamageTarget = (move, user) ->
      if util.typeEffectiveness(move.type, user.types) > 1
        0xC00
      else
        0x1000

makeFilterAbility("Filter")
makeFilterAbility("Solid Rock")

makeContactStatusAbility = (name, attachment) ->
  makeAbility name, ->
    this::isAliveCheck = -> true

    this::afterBeingHit = (move, user, target, damage, isDirect) ->
      return  if !move.hasFlag("contact")
      return  if @battle.rng.next("contact status") >= .3
      return  if !isDirect
      @pokemon.activateAbility()
      user.attach(attachment, source: @pokemon)

makeContactStatusAbility("Cute Charm", Attachment.Attract)
makeContactStatusAbility("Flame Body", Status.Burn)
makeContactStatusAbility("Poison Point", Status.Poison)
makeContactStatusAbility("Static", Status.Paralyze)

makeStatusBoostAbility = (name, statuses, spectra) ->
  makeAbility name, ->
    this::modifyBasePower = (move, target) ->
      if move.spectra == spectra && statuses.some((s) => @pokemon.has(s))
        0x1800
      else
        0x1000

makeStatusBoostAbility("Flare Boost", [Status.Burn], 'special')
makeStatusBoostAbility("Toxic Boost", [Status.Poison, Status.Toxic], 'physical')

makeHugePowerAbility = (name) ->
  makeAbility name, ->
    this::modifyAttack = (move) ->
      if move.isPhysical() then 0x2000 else 0x1000

makeHugePowerAbility("Huge Power")
makeHugePowerAbility("Pure Power")

makeAttachmentImmuneAbility = (name, immuneAttachments, options = {}) ->
  makeAbility name, ->
    this::shouldAttach = (attachment) ->
      if attachment in immuneAttachments
        @pokemon.activateAbility()
        return false
      return true

    shouldCure = options.cure ? true
    if shouldCure
      this::update = ->
        for attachment in immuneAttachments
          if @pokemon.has(attachment)
            @pokemon.activateAbility()
            @pokemon.unattach(attachment)

makeAttachmentImmuneAbility("Immunity", [Status.Poison, Status.Toxic])
makeAttachmentImmuneAbility("Inner Focus", [Attachment.Flinch], cure: false)
makeAttachmentImmuneAbility("Insomnia", [Status.Sleep])
makeAttachmentImmuneAbility("Limber", [Status.Paralyze])
makeAttachmentImmuneAbility("Magma Armor", [Status.Freeze])
makeAttachmentImmuneAbility("Oblivious", [Attachment.Attract])
makeAttachmentImmuneAbility("Own Tempo", [Attachment.Confusion])
makeAttachmentImmuneAbility("Vital Spirit", [Status.Sleep])
makeAttachmentImmuneAbility("Water Veil", [Status.Burn])

makeContactHurtAbility = (name) ->
  makeAbility name, ->
    this::isAliveCheck = -> true

    this::afterBeingHit = (move, user, target, damage, isDirect) ->
      return  unless move.hasFlag('contact')
      return  unless isDirect
      amount = user.stat('hp') >> 3
      @pokemon.activateAbility()
      if user.damage(amount)
        @battle.cannedText('POKEMON_HURT', user)

makeContactHurtAbility("Iron Barbs")
makeContactHurtAbility("Rough Skin")

makeRedirectAndBoostAbility = (name, type) ->
  makeAbility name, ->
    # TODO: This should be implemented as isImmune instead.
    # TODO: Type-immunities should come before ability immunities.
    this::shouldBlockExecution = (move, user) ->
      return  if move.getType(@battle, user, @pokemon) != type || user == @pokemon
      @pokemon.activateAbility()
      @pokemon.boost(specialAttack: 1)  unless @pokemon.isImmune(type)
      return true

makeRedirectAndBoostAbility("Lightningrod", "Electric")
makeRedirectAndBoostAbility("Storm Drain", "Water")

makeTypeImmuneAbility = (name, type, stat) ->
  makeAbility name, ->
    this::shouldBlockExecution = (move, user) ->
      return  if move.getType(@battle, user, @pokemon) != type || user == @pokemon
      @pokemon.activateAbility()
      @battle.message "#{@pokemon.name}'s #{name} increased its #{stat}!"
      hash = {}
      hash[stat] = 1
      @pokemon.boost(hash)
      return true

makeTypeImmuneAbility("Motor Drive", "Electric", "speed")
makeTypeImmuneAbility("Sap Sipper", "Grass", "attack")

makeTypeAbsorbMove = (name, type) ->
  makeAbility name, ->
    this::shouldBlockExecution = (move, user) ->
      return  if move.getType(@battle, user, @pokemon) != type || user == @pokemon
      @pokemon.activateAbility()
      amount = @pokemon.stat('hp') >> 2
      if @pokemon.heal(amount)
        @battle.cannedText('RECOVER_HP', @pokemon)
      return true

makeTypeAbsorbMove("Water Absorb", "Water")
makeTypeAbsorbMove("Volt Absorb", "Electric")

makeAbilityCancelAbility = (name, cannedText) ->
  makeAbility name, ->
    this::switchIn = ->
      @pokemon.activateAbility()
      @battle.cannedText(cannedText, @pokemon)

    this::beforeMove = (move, pokemon, targets) ->
      for target in targets
        continue  if !@battle.isPokemon(target)
        target.attach(Attachment.AbilityCancel)

    this::afterMove = (move, pokemon, targets) ->
      for target in targets
        continue  if !@battle.isPokemon(target)
        target.unattach(Attachment.AbilityCancel)

makeAbilityCancelAbility('Mold Breaker', 'MOLD_BREAKER')
makeAbilityCancelAbility('Teravolt', 'TERAVOLT')
makeAbilityCancelAbility('Turboblaze', 'TURBOBLAZE')

# Unique Abilities

makeAbility "Adaptability"

makeAbility "Aftermath", ->
  this::isAliveCheck = -> true

  this::afterFaint = ->
    hit = @pokemon.lastHitBy
    return  if !hit
    {team, slot, damage, move, turn} = hit
    pokemon = team.at(slot)
    if move.hasFlag('contact')
      amount = (pokemon.stat('hp') >> 2)
      @pokemon.activateAbility()
      pokemon.damage(amount)
      @battle.cannedText('POKEMON_HURT', pokemon)

makeAbility 'Analytic', ->
  this::modifyBasePower = ->
    if !@battle.hasActionsLeft() then 0x14CD else 0x1000

makeAbility "Anger Point", ->
  this::informCriticalHit = ->
    @pokemon.activateAbility()
    @battle.message "#{@pokemon.name} maxed its Attack!"
    @pokemon.boost(attack: 12)

makeAbility "Anticipation", ->
  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    moves = _(opponent.moves  for opponent in opponents).flatten()
    for move in moves
      effectiveness = util.typeEffectiveness(move.type, @pokemon.types) > 1
      if effectiveness || move.hasFlag("ohko")
        @pokemon.activateAbility()
        @battle.cannedText('ANTICIPATION', @pokemon)
        break

makeAbility "Arena Trap", ->
  this::beginTurn = this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    for opponent in opponents
      opponent.blockSwitch()  unless opponent.isImmune("Ground")

makeAbility "Bad Dreams", ->
  this::endTurn = ->
    opponents = @battle.getOpponents(@pokemon)
    for opponent in opponents
      continue  unless opponent.has(Status.Sleep)
      amount = opponent.stat('hp') >> 3
      @pokemon.activateAbility()
      if opponent.damage(amount)
        @battle.cannedText('BAD_DREAMS', opponent)

makeAbility "Color Change", ->
  this::afterBeingHit = (move, user, target, damage) ->
    {type} = move
    if !move.isNonDamaging() && !target.hasType(type)
      @pokemon.activateAbility()
      @battle.cannedText('COLOR_CHANGE', target, type)
      target.types = [ type ]

makeAbility "Compoundeyes", ->
  this::editAccuracy = (accuracy) ->
    Math.floor(1.3 * accuracy)

# Hardcoded in Pokemon#boost
makeAbility "Contrary"

makeAbility "Cursed Body", ->
  this::isAliveCheck = -> true

  this::afterBeingHit = (move, user, target, damage, isDirect) ->
    return  if !isDirect
    return  if user == target
    return  if user.has(Attachment.Substitute)
    return  if @battle.rng.next("cursed body") >= .3
    return  if user.has(Attachment.Disable)
    @pokemon.activateAbility()
    user.attach(Attachment.Disable, {move})

# Implementation is done in moves.coffee, specifically makeExplosionMove.
makeAbility 'Damp'

makeAbility 'Defeatist', ->
  this::modifyAttack = ->
    halfHP = (@pokemon.stat('hp') >> 1)
    if @pokemon.currentHP <= halfHP then 0x800 else 0x1000

makeAbility 'Defiant', ->
  this::afterEachBoost = (boostAmount, source) ->
    return  if source.team == @pokemon.team
    @pokemon.activateAbility()
    @pokemon.boost(attack: 2)  if boostAmount < 0

makeAbility 'Download', ->
  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    return  if opponents.length == 0
    totalDef = opponents.reduce(((s, p) -> s + p.stat('defense')), 0)
    totalSpDef = opponents.reduce(((s, p) -> s + p.stat('specialDefense')), 0)
    @pokemon.activateAbility()
    if totalSpDef <= totalDef
      @pokemon.boost(specialAttack: 1)
    else
      @pokemon.boost(attack: 1)

makeAbility 'Dry Skin', ->
  this::modifyBasePowerTarget = (move, user) ->
    if move.getType(@battle, user, @pokemon) == 'Fire' then 0x1400 else 0x1000

  this::endTurn = ->
    amount = (@pokemon.stat('hp') >> 3)
    if @battle.hasWeather(Weather.SUN)
      @pokemon.activateAbility()
      @pokemon.damage(amount)
    else if @battle.hasWeather(Weather.RAIN)
      @pokemon.activateAbility()
      @pokemon.heal(amount)

  this::shouldBlockExecution = (move, user) ->
    return  if move.getType(@battle, user, @pokemon) != 'Water' || user == @pokemon
    @pokemon.activateAbility()
    @pokemon.heal((@pokemon.stat('hp') >> 2))
    return true

# Implementation is in Attachment.Sleep
makeAbility 'Early Bird'

makeAbility 'Effect Spore', ->
  this::isAliveCheck = -> true

  this::afterBeingHit = (move, user, target, damage) ->
    return  unless move.hasFlag("contact")
    switch @battle.rng.randInt(1, 10, "effect spore")
      when 1
        if user.attach(Status.Sleep)
          @pokemon.activateAbility()
      when 2
        if user.attach(Status.Paralyze)
          @pokemon.activateAbility()
      when 3
        if user.attach(Status.Poison)
          @pokemon.activateAbility()

makeAbility 'Flash Fire', ->
  this::shouldBlockExecution = (move, user) ->
    return  if move.getType(@battle, user, @pokemon) != 'Fire' || user == @pokemon
    if @pokemon.attach(Attachment.FlashFire)
      @pokemon.activateAbility()
      @battle.cannedText('FLASH_FIRE', @pokemon)
    else
      @battle.cannedText('IMMUNITY', @pokemon)
    return true

makeAbility 'Forecast'

makeAbility 'Forewarn', ->
  VariablePowerMoves =
    'Crush Grip'   : true
    'Dragon Rage'  : true
    'Endeavor'     : true
    'Flail'        : true
    'Frustration'  : true
    'Grass Knot'   : true
    'Gyro Ball'    : true
    'SonicBoom'    : true
    'Hidden Power' : true
    'Low Kick'     : true
    'Natural Gift' : true
    'Night Shade'  : true
    'Psywave'      : true
    'Return'       : true
    'Reversal'     : true
    'Seismic Toss' : true
    'Trump Card'   : true
    'Wring Out'    : true

  CounterMoves =
    "Counter"     : true
    "Mirror Coat" : true
    "Metal Burst" : true

  @consider = consider = (move) ->
    if move.hasFlag('ohko')
      160
    else if CounterMoves[move.name]
      120
    else if VariablePowerMoves[move.name]
      80
    else
      move.power

  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    return  if opponents.length == 0
    moves = _(opponent.moves  for opponent in opponents).flatten()
    maxPower = Math.max(moves.map((m) -> consider(m))...)
    possibles = moves.filter((m) -> consider(m) == maxPower)
    finalMove = @battle.rng.choice(possibles, "forewarn")
    pokemon = _(opponents).find((p) -> finalMove in p.moves)
    @pokemon.activateAbility()
    @battle.cannedText('FOREWARN', pokemon, finalMove)

makeAbility 'Friend Guard', ->
  this::modifyDamageTarget = (move, user) ->
    return 0xC00  if user.team == @pokemon.team
    return 0x1000

makeAbility "Frisk", ->
  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    return  if opponents.length == 0
    # TODO: Do you select from opponents with items, or all alive opponents?
    opponent  = @battle.rng.choice(opponents, "frisk")
    if opponent.hasItem()
      @pokemon.activateAbility()
      item = opponent.getItem()
      @battle.cannedText('FRISK', @pokemon, item)

# Implemented in items.coffee; makePinchBerry
makeAbility "Gluttony"

makeAbility "Guts", ->
  this::modifyAttack = (move, target) ->
    return 0x1800  if @pokemon.hasStatus() && move.isPhysical()
    return 0x1000

makeAbility 'Harvest', ->
  this::endTurn = ->
    return  unless @pokemon.lastItem?.type == 'berries'
    shouldHarvest = @battle.hasWeather(Weather.SUN)
    shouldHarvest ||= @battle.rng.randInt(0, 1, "harvest") == 1
    if shouldHarvest
      @pokemon.activateAbility()
      @battle.cannedText('HARVEST', @pokemon, @pokemon.lastItem)
      @pokemon.setItem(@pokemon.lastItem, clearLastItem: true)

makeAbility 'Healer', ->
  this::endTurn = ->
    for adjacent in @pokemon.team.getAdjacent(@pokemon)
      if @battle.rng.randInt(1, 10, "healer") <= 3
        @pokemon.activateAbility()
        adjacent.cureStatus()

makeAbility 'Heatproof', ->
  this::modifyBasePowerTarget = (move, user) ->
    return 0x800  if move.getType(@battle, user, @pokemon) == 'Fire'
    return 0x1000

makeAbility 'Heavy Metal', ->
  this::calculateWeight = (weight) ->
    2 * weight

makeAbility 'Honey Gather'

makeAbility 'Hustle', ->
  this::modifyAttack = (move, target) ->
    return 0x1800  if move.isPhysical()
    return 0x1000

  this::editAccuracy = (accuracy, move) ->
    return Math.floor(0.8 * accuracy)  if move.isPhysical()
    return accuracy

makeAbility "Hydration", ->
  this::endTurn = ->
    if @battle.hasWeather(Weather.RAIN) && @pokemon.hasStatus()
      @pokemon.activateAbility()
      @pokemon.cureStatus()

makeAbility 'Ice Body', ->
  this::endTurn = ->
    if @battle.hasWeather(Weather.HAIL)
      @pokemon.activateAbility()
      amount = @pokemon.stat('hp') >> 4
      @pokemon.heal(amount)

  this::isWeatherDamageImmune = (weather) ->
    return true  if weather == Weather.HAIL

makeAbility 'Illuminate'

makeAbility 'Imposter', ->
  this::switchIn = ->
    opponents = @battle.getAllOpponents(@pokemon)
    index = @team.indexOf(@pokemon)
    opponent = opponents[index]
    return  if !opponent
    return  if opponent.isFainted() || opponent.has(Attachment.Substitute)
    @pokemon.attach(Attachment.Transform, target: opponent)

# Hardcoded in Move#isDirectHit
# Hardcoded in Attachment.Reflect and Attachment.LightScreen
makeAbility 'Infiltrator'

makeAbility 'Intimidate', ->
  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    for opponent in opponents
      unless opponent.has(Attachment.Substitute)
        @pokemon.activateAbility()
        opponent.boost(attack: -1, @pokemon)

makeAbility 'Iron Fist', ->
  this::modifyBasePower = (move) ->
    if move.hasFlag('punch') then 0x1333 else 0x1000

makeAbility 'Justified', ->
  this::afterBeingHit = (move, user, target, damage, isDirect) ->
    if !move.isNonDamaging() && move.getType(@battle, user, @pokemon) == 'Dark' && isDirect
      @pokemon.activateAbility()
      @pokemon.boost(attack: 1)

makeAbility 'Klutz', ->
  this::beginTurn = this::switchIn = ->
    @pokemon.blockItem()

makeAbility 'Leaf Guard', ->
  this::shouldAttach = (attachment) ->
    if attachment.status && @battle.hasWeather(Weather.SUN)
      @pokemon.activateAbility()
      return false
    return true

makeAbility 'Levitate', ->
  this::isImmune = (type) ->
    return true  if type == 'Ground'

makeAbility 'Light Metal', ->
  this::calculateWeight = (weight) ->
    weight >> 1

# Implemented in Pokemon#drain
makeAbility 'Liquid Ooze'

makeAbility 'Magic Bounce', ->
  this::beginTurn = this::switchIn = ->
    @pokemon.attach(Attachment.MagicCoat)
    @team.attach(Attachment.MagicCoat)

makeAbility 'Magic Guard', ->
  this::transformHealthChange = (damage, options) ->
    switch options.source
      when 'move' then return damage
      else return 0

makeAbility 'Magnet Pull', ->
  this::beginTurn = this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    opponents = opponents.filter((p) -> p.hasType("Steel"))
    opponent.blockSwitch()  for opponent in opponents

makeAbility 'Marvel Scale', ->
  this::editDefense = (defense) ->
    if @pokemon.hasStatus() then Math.floor(1.5 * defense) else defense

makeAbility 'Minus', ->
  this::modifyAttack = (move, target) ->
    allies = @team.getActiveAlivePokemon()
    if move.isSpecial() && allies.some((p) -> p.has(Ability.Plus))
      0x1800
    else
      0x1000

makeAbility 'Moody', ->
  allBoosts = [ "attack", "defense", "speed", "specialAttack",
                "specialDefense", "accuracy", "evasion" ]
  this::endTurn = ->
    possibleRaises = allBoosts.filter (stat) =>
      @pokemon.stages[stat] < 6
    raiseStat = @battle.rng.choice(possibleRaises, "moody raise")

    possibleLowers = allBoosts.filter (stat) =>
      @pokemon.stages[stat] > -6 && stat != raiseStat
    lowerStat = @battle.rng.choice(possibleLowers, "moody lower")

    boosts = {}
    boosts[raiseStat] = 2   if raiseStat
    boosts[lowerStat] = -1  if lowerStat
    @pokemon.activateAbility()
    @pokemon.boost(boosts)

makeAbility 'Moxie', ->
  this::afterSuccessfulHit = (move, user, target) ->
    if target.isFainted()
      @pokemon.activateAbility()
      @pokemon.boost(attack: 1)

makeAbility 'Multiscale', ->
  this::modifyDamageTarget = ->
    return 0x800  if @pokemon.currentHP == @pokemon.stat('hp')
    return 0x1000

makeAbility 'Multitype'

makeAbility 'Mummy', ->
  this::isAliveCheck = -> true

  this::afterBeingHit = (move, user) ->
    if move.hasFlag("contact") && user.hasChangeableAbility() && !user.hasAbility("Mummy")
      @pokemon.activateAbility()
      user.copyAbility(@constructor)
      @battle.cannedText('MUMMY', user)

makeAbility 'Natural Cure', ->
  this::switchOut = ->
    @pokemon.cureStatus(message: false)

# Hardcoded in Move#willMiss
makeAbility 'No Guard'

makeAbility 'Normalize', ->
  this::editMoveType = (type, target) ->
    return "Normal"  if @pokemon != target
    return type

makeAbility 'Overcoat', ->
  this::isWeatherDamageImmune = -> true

makeAbility 'Pickpocket', ->
  this::afterBeingHit = (move, user, target, damage) ->
    return  if !move.hasFlag("contact") || target.hasItem() || !user.canLoseItem()
    @pokemon.activateAbility()
    @battle.cannedText('PICKPOCKET', target, user, user.item)
    target.setItem(user.item)
    user.removeItem()

makeAbility 'Plus', ->
  this::modifyAttack = (move, target) ->
    allies = @team.getActiveAlivePokemon()
    if move.isSpecial() && allies.some((p) -> p.has(Ability.Minus))
      0x1800
    else
      0x1000

makeAbility 'Poison Heal', ->
  # Poison damage neutralization is hardcoded in Attachment.Poison and Toxic.
  this::endTurn = ->
    # Return early so that:
    # 1. We don't trigger ability activation if the pokemon won't be healed.
    # 2. Ability activation must happen before HP animation.
    return  if @pokemon.currentHP == @pokemon.stat('hp')
    if @pokemon.has(Status.Poison) || @pokemon.has(Status.Toxic)
      @pokemon.activateAbility()
      amount = @pokemon.stat('hp') >> 3
      @pokemon.heal(amount)

makeAbility 'Prankster', ->
  this::editPriority = (priority, move) ->
    return priority + 1  if move.isNonDamaging()
    return priority

# PP deduction hardcoded in Battle
makeAbility 'Pressure', ->
  this::switchIn = ->
    @pokemon.activateAbility()
    @battle.cannedText('PRESSURE', @pokemon)

# Speed drop negation hardcoded into Attachment.Paralyze
makeAbility 'Quick Feet', ->
  this::editSpeed = (speed) ->
    if @pokemon.hasStatus() then Math.floor(1.5 * speed) else speed

makeAbility 'Rain Dish', ->
  this::endTurn = ->
    return  unless @battle.hasWeather(Weather.RAIN)
    @pokemon.activateAbility()
    amount = @pokemon.stat('hp') >> 4
    @pokemon.heal(amount)

makeAbility 'Rattled', ->
  this::afterBeingHit = (move, user, target, damage, isDirect) ->
    type = move.getType(@battle, user, @pokemon)
    if type in [ "Bug", "Ghost", "Dark" ] && !move.isNonDamaging() && isDirect
      @pokemon.activateAbility()
      @pokemon.boost(speed: 1)

makeAbility 'Reckless', ->
  this::modifyBasePower = (move, target) ->
    kickMoves = [ @battle.getMove("Jump Kick"), @battle.getMove("Hi Jump Kick")]
    if move.recoil < 0 || move in kickMoves
      0x1333
    else
      0x1000

makeAbility 'Rivalry', ->
  this::modifyBasePower = (move, target) ->
    return 0x1400  if @pokemon.gender == target.gender
    return 0xC00   if (@pokemon.gender == 'F' && target.gender == 'M') ||
                      (@pokemon.gender == 'M' && target.gender == 'F')
    return 0x1000

makeAbility 'Regenerator', ->
  this::switchOut = ->
    amount = Math.floor(@pokemon.stat('hp') / 3)
    # Uses setHP directly to bypass Heal Block's effect
    @pokemon.setHP(@pokemon.currentHP + amount)

# Hardcoded in move.coffee
makeAbility 'Rock Head'

makeAbility 'Run Away'

makeAbility 'Sand Force', ->
  this::modifyBasePower = (move, target) ->
    return 0x1000  unless @battle.hasWeather(Weather.SAND)
    type = move.getType(@battle, @pokemon, target)
    return 0x14CD  if type in ['Rock', 'Ground', 'Steel']
    return 0x1000

  this::isWeatherDamageImmune = (weather) ->
    return true  if weather == Weather.SAND

makeAbility 'Sand Veil', ->
  this::editEvasion = (accuracy) ->
    if @battle.hasWeather(Weather.SAND)
      Math.floor(.8 * accuracy)
    else
      accuracy

  this::isWeatherDamageImmune = (weather) ->
    return true  if weather == Weather.SAND

makeAbility 'Scrappy', ->
  this::shouldIgnoreImmunity = (moveType, target) ->
    return target.hasType('Ghost') && moveType in [ 'Normal', 'Fighting' ]

# Hardcoded in server/bw/data/moves
makeAbility 'Serene Grace'

makeAbility 'Shadow Tag', ->
  this::beginTurn = this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    for opponent in opponents
      opponent.blockSwitch()  unless opponent.hasAbility('Shadow Tag')

makeAbility 'Shed Skin', ->
  this::endTurn = ->
    return  unless @pokemon.hasStatus()
    if @battle.rng.randInt(1, 10, "shed skin") <= 3
      @pokemon.cureStatus()

makeAbility 'Sheer Force', ->
  this::modifyBasePower = (move, target) ->
    return 0x14CD  if move.hasSecondaryEffect()
    return 0x1000

# Hardcoded in Move#shouldTriggerSecondary
makeAbility 'Shield Dust'

makeAbility 'Simple', ->
  this::transformBoosts = (boosts) ->
    newBoosts = {}
    for stat, boost of boosts
      newBoosts[stat] = 2 * boost
    newBoosts

makeAbility "Skill Link", ->
  this::calculateNumberOfHits = (move, targets) ->
    move.maxHits

makeAbility 'Slow Start', ->
  this::initialize = ->
    @turns = 5

  this::switchIn = ->
    @pokemon.activateAbility()
    @battle.cannedText('SLOW_START_START', @pokemon)

  this::endTurn = ->
    @turns -= 1
    if @turns == 0
      @battle.cannedText('SLOW_START_END', @pokemon)

  this::modifyAttack = (move, target) ->
    return 0x800  if move.isPhysical() && @turns > 0
    return 0x1000

  this::editSpeed = (speed) ->
    return speed >> 1  if @turns > 0
    return speed

makeAbility 'Sniper', ->
  this::modifyDamage = (move, target) ->
    return 0x1800  if @pokemon.crit
    return 0x1000

makeAbility 'Snow Cloak', ->
  this::editEvasion = (accuracy) ->
    if @battle.hasWeather(Weather.HAIL)
      Math.floor(.8 * accuracy)
    else
      accuracy

  this::isWeatherDamageImmune = (weather) ->
    return true  if weather == Weather.HAIL

makeAbility 'Solar Power', ->
  this::modifyAttack = (move, target) ->
    return 0x1800  if move.isSpecial() && @battle.hasWeather(Weather.SUN)
    return 0x1000

  this::endTurn = ->
    if @battle.hasWeather(Weather.SUN)
      amount = (@pokemon.stat('hp') >> 3)
      @pokemon.activateAbility()
      @pokemon.damage(amount)
      @battle.cannedText('POKEMON_HURT', @pokemon)

makeAbility 'Soundproof', ->
  this::isImmune = (type, move) ->
    return true  if move?.hasFlag('sound')

makeAbility 'Speed Boost', ->
  this::endTurn = ->
    return  if @pokemon.turnsActive <= 0
    @pokemon.boost(speed: 1)

makeAbility 'Stall', ->
  this::afterTurnOrder = ->
    @battle.delay(@pokemon)

# Hardcoded in Attachment.Flinch
makeAbility 'Steadfast'

# Hardcoded in Pokemon#canLoseItem
makeAbility 'Sticky Hold'

makeAbility 'Sturdy', ->
  this::transformHealthChange = (amount, options) ->
    if @pokemon.currentHP == @pokemon.stat('hp')
      if amount >= @pokemon.currentHP && options.source == 'move'
        @pokemon.activateAbility()
        @battle.cannedText('ENDURE', @pokemon)
        return @pokemon.currentHP - 1
    return amount

makeAbility 'Suction Cups', ->
  this::shouldPhase = (phaser) ->
    @pokemon.activateAbility()
    @battle.cannedText('ANCHOR', @pokemon)
    return false

# Hardcoded in Move#criticalHitLevel
makeAbility 'Super Luck'

# Hardcoded in status.coffee
makeAbility 'Synchronize'

makeAbility 'Tangled Feet', ->
  this::editEvasion = (evasion) ->
    if @pokemon.has(Attachment.Confusion) then evasion >> 1 else evasion

makeAbility 'Technician', ->
  this::modifyBasePower = (move, target) ->
    return 0x1800  if move.basePower(@battle, @pokemon, target) <= 60
    return 0x1000

makeAbility 'Telepathy', ->
  this::shouldBlockExecution = (move, user) ->
    return  if move.isNonDamaging() || user == @pokemon
    return  if user not in @team.pokemon
    @pokemon.activateAbility()
    @battle.cannedText('AVOID_ALLIES', @pokemon)
    return true

makeAbility 'Thick Fat', ->
  this::modifyAttackTarget = (move, user) ->
    return 0x800  if move.getType(@battle, user, @pokemon) in [ 'Fire', 'Ice' ]
    return 0x1000

makeAbility 'Tinted Lens', ->
  this::modifyDamage = (move, target) ->
    return 0x2000  if move.typeEffectiveness(@battle, @pokemon, target) < 1
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

  this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    abilities = _(opponent.ability  for opponent in opponents).compact()
    abilities = abilities.filter((a) -> a.displayName not of bannedAbilities)
    return  if abilities.length == 0
    ability = @battle.rng.choice(abilities, "trace")
    # TODO: Display whose ability it traced.
    @pokemon.copyAbility(ability)
    @battle.cannedText('TRACE', ability)

makeAbility 'Truant', ->
  this::initialize = ->
    @truanted = true

  this::beforeMove = ->
    @truanted = !@truanted
    if @truanted
      @pokemon.activateAbility()
      @battle.cannedText('TRUANT', @pokemon)
      return false

# Hardcoded in Move
makeAbility "Unaware"

# Hardcoded in Pokemon#removeItem
makeAbility 'Unburden'

makeAbility 'Unnerve', ->
  this::beginTurn = this::switchIn = ->
    opponents = @battle.getOpponents(@pokemon)
    # TODO: Unnerve likely doesn't last until the end of the turn.
    # More research is needed here.
    for opponent in opponents
      opponent.blockItem()  if opponent.item?.type == 'berries'

makeAbility 'Victory Star', ->
  this::editAccuracy = (accuracy) ->
    Math.floor(accuracy * 1.1)

makeAbility 'Weak Armor', ->
  this::afterBeingHit = (move, user) ->
    if move.isPhysical() then @pokemon.boost(defense: -1, speed: 1)

makeAbility 'Wonder Guard', ->
  this::shouldBlockExecution = (move, user) ->
    return  if move == @battle.getMove("Struggle")
    return  if move.isNonDamaging() || user == @pokemon
    return  if move.typeEffectiveness(@battle, user, @pokemon) > 1
    @pokemon.activateAbility()
    return true

# Hardcoded in Move#chanceToHit
makeAbility 'Wonder Skin'
