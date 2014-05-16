@ItemData = ItemData = require './data_items.json'
{SpeciesData} = require './pokemon'
{Attachment, Status, VolatileAttachment} = require('../attachment')
{Weather} = require '../../../shared/weather'
{Protocol} = require '../../../shared/protocol'
util = require '../util'

@Item = Item = {}

makeItem = (name, func) ->
  if name not of ItemData
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")
  condensed = name.replace(/\s+/g, '')
  class Item[condensed] extends VolatileAttachment
    @displayName: name
    displayName: name
    item: true
    (this[property] = value  for property, value of ItemData[name])
    func?.call(this)

makePinchBerry = (name, hookName, func) ->
  if !func?
    func = hookName
    hookName = "update"

  makeItem name, ->
    this.eat = (battle, eater) ->
      func.call(this, battle, eater)

    this::[hookName] = ->
      fraction     = (if @pokemon.hasAbility("Gluttony") then 1 else 2)
      activationHP = @pokemon.stat('hp') >> fraction
      if @pokemon.currentHP <= activationHP
        @constructor.eat(@battle, @pokemon)
        @pokemon.useItem()

# TODO: If the stat is maxed, does anything special happen?
#       Is the berry still consumed?
makeStatBoostBerry = (name, boosts) ->
  makePinchBerry name, (battle, eater) ->
    boostedStats = eater.boost(boosts)

makeFlavorHealingBerry = (name, stat) ->
  makeItem name, ->
    this.eat = (battle, owner) ->
      # TODO: Replace with the real battle message.
      battle.message "#{owner.name}'s #{name} restored its HP a little!"
      owner.heal(Math.floor(owner.stat('hp') / 8))
      if owner.natureBoost(stat) < 1.0
        # TODO: Replace with the real battle message.
        battle.message "The #{name} was bitter!"
        owner.attach(Attachment.Confusion)

    this::update = ->
      if @pokemon.currentHP <= Math.floor(@pokemon.stat('hp') / 2)
        @constructor.eat(@battle, @pokemon)
        @pokemon.useItem()

makeHealingBerry = (name, func) ->
  makeItem name, ->
    this.eat = (battle, owner) ->
      # TODO: Replace with the real battle message.
      battle.message "#{owner.name}'s #{name} restored its HP a little!"
      owner.heal(func(owner))

    this::update = ->
      if @pokemon.currentHP <= Math.floor(@pokemon.stat('hp') / 2)
        @constructor.eat(@battle, @pokemon)
        @pokemon.useItem()

makeTypeResistBerry = (name, type) ->
  makeItem name, ->
    this.eat = ->
    this::modifyBasePowerTarget = (move, user) ->
      return 0x1000  if move.getType(@battle, user, @pokemon) != type
      return 0x1000  if util.typeEffectiveness(type, @pokemon.types) <= 1 && type != 'Normal'
      @battle.message "The #{name} weakened the damage to #{@pokemon.name}!"
      @pokemon.useItem()
      return 0x800

makeFeedbackDamageBerry = (name, klass) ->
  makeItem name, ->
    this.eat = ->
    this::afterBeingHit = (move, user, target) ->
      return  if !move[klass]()
      return  if target.isFainted()
      if user.damage(Math.floor(user.stat('hp') / 8))
        # TODO: Real message.
        @battle.message "The #{name} hurt #{user.name}!"
      target.useItem()

makeStatusCureBerry = (name, statuses...) ->
  makeItem name, ->
    this.eat = (battle, owner) ->
      for attachment in statuses
        if owner.cureAttachment(attachment, message: name)
          return true
      return false

    this::update = ->
      if @constructor.eat(@battle, @pokemon) then @pokemon.useItem()

makeOrbItem = (name, species) ->
  species = SpeciesData[species]
  makeItem name, ->
    this::modifyBasePower = (move, target) ->
      if @pokemon.species == species && move.type in @pokemon.types
        0x1333
      else
        0x1000

makeStatusOrbItem = (name, status) ->
  makeItem name, ->
    this::endTurn = ->
      @pokemon.attach(status)

makeTypeBoostItem = (name, type) ->
  makeItem name, ->
    this::modifyBasePower = (move, target) ->
      if move.type == type
        0x1333
      else
        0x1000

# Same as makeTypeBoostItem, but sets item.plate = type.
makePlateItem = (name, type) ->
  makeTypeBoostItem(name, type)
  makeItem(name, -> @plate = type)

# Gem items are one-time use.
GEM_BOOST_AMOUNT = GEM_BOOST_AMOUNT ? 0x1800
makeGemItem = (name, type) ->
  makeItem name, ->
    this::modifyBasePower = (move, target) ->
      if move.type == type
        GEM_BOOST_AMOUNT
      else
        0x1000

    this::afterSuccessfulHit = (move, user, target) ->
      if move.type == type
        @battle.message "The #{@displayName} strengthened #{move.name}'s power!"
        user.useItem()

makeChoiceItem = (name, func) ->
  makeItem name, ->
    this::initialize = ->
      @move = null

    this::beforeMove = (move, user, targets) ->
      @move = move
      true

    this::beginTurn = ->
      @pokemon.lockMove(@move)  if @move?

    func.call(this)

makeWeatherItem = (name, weather) ->
  makeItem name, ->
    @lengthensWeather = weather

makeSpeciesBoostingItem = (name, speciesArray, statsHash) ->
  speciesArray = speciesArray.map (species) ->
    SpeciesData[species]
  makeItem name, ->
    for stat, boost of statsHash
      capitalizedStat = stat[0].toUpperCase() + stat.substr(1)
      # TODO: Use modifiers
      this::["edit#{capitalizedStat}"] = (stat) ->
        if @pokemon.species in speciesArray
          Math.floor(stat * boost)
        else
          stat

makeSpeciesCriticalItem = (name, species) ->
  species = SpeciesData[species]
  makeItem name, ->
    this::criticalModifier = (sum) ->
      sum + (if @pokemon.species == species then 2 else 0)

makeDelayItem = (name) ->
  makeItem name, ->
    this::afterTurnOrder = ->
      @battle.delay(@pokemon)

makeEvasionItem = (name, ratio=0.9) ->
  makeItem name, ->
    this::editEvasion = (accuracy) ->
      Math.floor(accuracy * ratio)

makeFlinchItem = (name) ->
  makeItem name, ->
    this::afterSuccessfulHit = (move, user, target) ->
      multiplier = (if user.hasAbility("Serene Grace") then 2 else 1)
      if move.flinchChance == 0 && !move.isNonDamaging() &&
          @battle.rng.next("flinch item chance") < .1 * multiplier
        target.attach(Attachment.Flinch)

makeCriticalBoostItem = (name) ->
  makeItem name, ->
    this::criticalModifier = (sum) -> sum + 1

makeBoostOnTypeItem = (name, type, boosts) ->
  stats = Object.keys(boosts)
  length = stats.length
  stats = stats.map (stat) ->
    stat[0].toUpperCase() + stat[1...length].replace(/[A-Z]/g, " $1")
  stats[length - 1] = "and #{stats[length - 1]}"  if length >= 2
  stats = stats.join(", ")  if length >= 3
  stats = stats.join(" ")   if length == 2
  makeItem name, ->
    this::afterBeingHit = (move, user, target) ->
      if move.type == type
        @battle.message "#{user.name}'s #{@displayName} made its #{stats} rise!"
        target.boost(boosts)
        target.useItem()

makeBoostOnTypeItem 'Absorb Bulb', 'Water', specialAttack: 1

makeOrbItem 'Adamant Orb', 'Dialga'
makeFlavorHealingBerry 'Aguav Berry', "specialDefense"

makeItem 'Air Balloon', ->
  this::initialize = ->
    @pokemon.tell(Protocol.POKEMON_ATTACH, @displayName)

  this::afterBeingHit = (move, user, target) ->
    return  if move.isNonDamaging()
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @displayName)
    target.removeItem()

  this::isImmune = (type) ->
    return true  if type == 'Ground'

makeStatBoostBerry 'Apicot Berry', specialDefense: 1
makeStatusCureBerry 'Aspear Berry', Status.Freeze
makeTypeResistBerry 'Babiri Berry', 'Steel'
makeHealingBerry 'Berry Juice', -> 20
makeTypeBoostItem 'Black Belt', 'Fighting'
makeTypeBoostItem 'BlackGlasses', 'Dark'

makeItem 'Black Sludge', ->
  this::endTurn = ->
    maxHP = @pokemon.stat('hp')
    if @pokemon.hasType('Poison')
      return  if maxHP == @pokemon.currentHP
      amount = Math.floor(maxHP / 16)
      amount = 1  if amount == 0
      @battle.message "#{@pokemon.name} restored a little HP using its #{@displayName}!"
      @pokemon.heal(amount)
    else
      amount = Math.floor(maxHP / 8)
      amount = 1  if amount == 0
      if @pokemon.damage(amount)
        @battle.message "#{@pokemon.name} is hurt by its #{@displayName}!"

makeEvasionItem 'BrightPowder', 0.9
makeGemItem 'Bug Gem', 'Bug'
makeBoostOnTypeItem 'Cell Battery', 'Electric', attack: 1
makeTypeBoostItem 'Charcoal', 'Fire'
makeTypeResistBerry 'Charti Berry', 'Rock'
makeStatusCureBerry 'Cheri Berry', Status.Paralyze
makeStatusCureBerry 'Chesto Berry', Status.Sleep
makeTypeResistBerry 'Chilan Berry', 'Normal'
makeChoiceItem 'Choice Band', ->
  this::modifyAttack = (move) ->
    if move.isPhysical() then 0x1800 else 0x1000

makeChoiceItem 'Choice Specs', ->
  this::modifyAttack = (move) ->
    if move.isSpecial() then 0x1800 else 0x1000

makeChoiceItem 'Choice Scarf', ->
  this::editSpeed = (stat) ->
    Math.floor(stat * 1.5)

makeTypeResistBerry 'Chople Berry', 'Fighting'
makeTypeResistBerry 'Coba Berry', 'Flying'
makeTypeResistBerry 'Colbur Berry', 'Dark'

makePinchBerry 'Custap Berry', 'afterTurnOrder', (battle, eater) ->
  battle.cannedText('MOVE_FIRST', eater, this)
  battle.bump(eater)

makeWeatherItem 'Damp Rock', Weather.RAIN
makeGemItem 'Dark Gem', 'Dark'
makeTypeBoostItem 'Dragon Fang', 'Dragon'
makeGemItem 'Dragon Gem', 'Dragon'
makePlateItem 'Draco Plate', 'Dragon'
makePlateItem 'Dread Plate', 'Dark'
makePlateItem 'Earth Plate', 'Ground'

makeItem 'Eject Button', ->
  this::afterAllHitsTarget = (move, user) ->
    return  if move.isNonDamaging()
    return  if !@battle.forceSwitch(@pokemon)
    @battle.message "#{@pokemon.name} is switched out with the Eject Button!"
    @pokemon.useItem()

makeGemItem 'Electric Gem', 'Electric'

makeItem 'Enigma Berry', ->
  this.eat = ->
  this::afterBeingHit = (move, user, target) ->
    return  if util.typeEffectiveness(move.type, target.types) <= 1
    # TODO: real message
    @battle.message "The #{name} restored #{target.name}'s HP a little!"
    target.heal(Math.floor(target.stat('hp') / 4))
    target.useItem()

makeItem 'Eviolite', ->
  this::editDefense = this::editSpecialDefense = (defense) ->
    return Math.floor(1.5 * defense)  if @pokemon.nfe
    return defense

makeItem 'Expert Belt', ->
  this::modifyAttack = (move, target) ->
    effectiveness = move.typeEffectiveness(@battle, @pokemon, target)
    return 0x1333  if effectiveness > 1
    return 0x1000

makeGemItem 'Fighting Gem', 'Fighting'
makeFlavorHealingBerry 'Figy Berry', "attack"
makeGemItem 'Fire Gem', 'Fire'
makePlateItem 'Fist Plate', 'Fighting'
makeStatusOrbItem 'Flame Orb', Status.Burn
makePlateItem 'Flame Plate', 'Fire'
makeItem 'Float Stone', ->
  this::calculateWeight = (weight) ->
    Math.floor(weight / 2)
makeGemItem 'Flying Gem', 'Flying'

makeItem 'Focus Band', ->
  this::editDamage = (damage, move) ->
    if damage >= @pokemon.currentHP && @battle.rng.randInt(0, 9, "focus band") == 0
      @battle.message "#{@pokemon.name} hung on using its #{@displayName}!"
      @pokemon.useItem()
      return @pokemon.currentHP - 1
    return damage

makeItem 'Focus Sash', ->
  this::editDamage = (damage, move) ->
    maxHP = @pokemon.stat('hp')
    if @pokemon.currentHP == maxHP && damage >= maxHP
      @battle.message "#{@pokemon.name} hung on using its #{@displayName}!"
      @pokemon.useItem()
      return maxHP - 1
    return damage

makeDelayItem 'Full Incense'
makeStatBoostBerry 'Ganlon Berry', defense: 1
makeGemItem 'Ghost Gem', 'Ghost'
makeGemItem 'Grass Gem', 'Grass'
makeOrbItem 'Griseous Orb', 'Giratina'
makeGemItem 'Ground Gem', 'Ground'
makeTypeResistBerry 'Haban Berry', 'Dragon'
makeTypeBoostItem 'Hard Stone', 'Rock'
makeWeatherItem 'Heat Rock', Weather.SUN
makeFlavorHealingBerry 'Iapapa Berry', "defense"
makeGemItem 'Ice Gem', 'Ice'
makePlateItem 'Icicle Plate', 'Ice'
makeWeatherItem 'Icy Rock', Weather.HAIL
makePlateItem 'Insect Plate', 'Bug'
makePlateItem 'Iron Plate', 'Steel'
makeFeedbackDamageBerry 'Jaboca Berry', 'isPhysical'
makeTypeResistBerry 'Kasib Berry', 'Ghost'
makeTypeResistBerry 'Kebia Berry', 'Poison'
makeFlinchItem "King's Rock"
makeDelayItem 'Lagging Tail'

# TODO: What happens if the Pokemon already has Focus Energy?
#       Does the berry still get eaten? Same goes for the other stat berries.
makePinchBerry 'Lansat Berry', (battle, eater) ->
  eater.attach(Attachment.FocusEnergy)

makeEvasionItem 'Lax Incense', 0.9

makeItem 'Leftovers', ->
  this::endTurn = ->
    maxHP = @pokemon.stat('hp')
    return  if maxHP == @pokemon.currentHP
    @battle.message "#{@pokemon.name} restored a little HP using its #{@displayName}!"
    amount = Math.floor(maxHP / 16)
    amount = 1  if amount == 0
    @pokemon.heal(amount)

makeStatBoostBerry 'Liechi Berry', attack: 1
makeItem 'Life Orb', ->
  this::modifyAttack = ->
    0x14CC

  this::afterAllHits = (move) ->
    return  if move.isNonDamaging()
    if @pokemon.damage(Math.floor(@pokemon.stat('hp') / 10))
      @battle.message "#{@pokemon.name} lost some of its HP!"

makeItem 'Light Clay' # Hardcoded in Attachment.Screen

makeStatusCureBerry 'Lum Berry', Status.Paralyze, Status.Sleep, Status.Poison,
  Status.Toxic, Status.Burn, Status.Freeze, Attachment.Confusion
makeOrbItem 'Lustrous Orb', 'Palkia'
makeItem 'Macho Brace', ->
  this::editSpeed = (stat) ->
    Math.floor(stat / 2)
makeTypeBoostItem 'Magnet', 'Electric'
makeFlavorHealingBerry 'Mago Berry', "speed"
makePlateItem 'Meadow Plate', 'Grass'

makeItem 'Mental Herb', ->
  this.activate = (battle, pokemon) ->
    for effectName in [ 'Attract', 'Taunt', 'Encore', 'Torment', 'Disable' ]
      attachment = Attachment[effectName]
      if pokemon.has(attachment)
        battle.cannedText('MENTAL_HERB', pokemon)
        pokemon.unattach(attachment)
        return true
    return false

  this::update = ->
    if @constructor.activate(@battle, @pokemon)
      @pokemon.useItem()

makeTypeBoostItem 'Metal Coat', 'Steel'

makeItem 'Metronome', ->
  this::modifyBasePower = (move, target) ->
    attachment = @pokemon.get(Attachment.Metronome)
    layers = attachment?.layers || 0
    0x1000 + layers * 0x333

  this::afterSuccessfulHit = (move, user, target) ->
    user.attach(Attachment.Metronome, {move})

makePinchBerry 'Micle Berry', (battle, eater) ->
  eater.attach(Attachment.MicleBerry)

makePlateItem 'Mind Plate', 'Psychic'
makeTypeBoostItem 'Miracle Seed', 'Grass'

makeItem 'Muscle Band', ->
  this::modifyBasePower = (move, target) ->
    if move.isPhysical()
      0x1199
    else
      0x1000

makeTypeBoostItem 'Mystic Water', 'Water'
makeTypeBoostItem 'NeverMeltIce', 'Ice'
makeGemItem 'Normal Gem', 'Normal'
makeTypeResistBerry 'Occa Berry', 'Fire'
makeTypeBoostItem 'Odd Incense', 'Psychic'
makeHealingBerry 'Oran Berry', -> 10
makeTypeResistBerry 'Passho Berry', 'Water'
makeTypeResistBerry 'Payapa Berry', 'Psychic'
makeStatusCureBerry 'Pecha Berry', Status.Toxic, Status.Poison
makeStatusCureBerry 'Persim Berry', Attachment.Confusion
makeStatBoostBerry 'Petaya Berry', specialAttack: 1
makeTypeBoostItem 'Poison Barb', 'Poison'
makeGemItem 'Poison Gem', 'Poison'
makeGemItem 'Psychic Gem', 'Psychic'

makeItem 'Quick Claw', ->
  this::afterTurnOrder = ->
    if @battle.rng.next("quick claw") < .2
      @battle.cannedText('MOVE_FIRST', @pokemon, @constructor)
      @battle.bump(@pokemon)

makeStatusCureBerry 'Rawst Berry', Status.Burn
makeFlinchItem "Razor Fang"

makeItem 'Red Card', ->
  this::afterAllHitsTarget = (move, user) ->
    return  if move.isNonDamaging()
    benched  = user.team.getAliveBenchedPokemon()
    return  if benched.length == 0
    @battle.message "#{@pokemon.name} held up its Red Card against #{user.name}!"
    @pokemon.useItem()
    return  if user.shouldPhase(@battle, @pokemon) == false
    pokemon = @battle.rng.choice(benched)
    index = user.team.indexOf(pokemon)
    user.team.switch(user, index)

makeTypeResistBerry 'Rindo Berry', 'Grass'
makeGemItem 'Rock Gem', 'Rock'

makeItem 'Rocky Helmet', ->
  this::isAliveCheck = -> true

  this::afterBeingHit = (move, user, target) ->
    if move.hasFlag("contact")
      amount = Math.floor(user.stat('hp') / 6)
      if user.damage(amount)
        @battle.message "#{user.name} was hurt by the #{@displayName}!"

makeTypeBoostItem 'Rock Incense', 'Rock'
makeTypeBoostItem 'Rose Incense', 'Grass'
makeFeedbackDamageBerry 'Rowap Berry', 'isSpecial'
makeStatBoostBerry 'Salac Berry', speed: 1
makeTypeBoostItem 'Sea Incense', 'Water'
makeTypeBoostItem 'Sharp Beak', 'Flying'

makeItem 'Shell Bell', ->
  this::afterSuccessfulHit = (move, user, target, damage) ->
    # TODO: Does Shell Bell display a message if the Pokemon is at full HP?
    return  if damage == 0
    user.heal(Math.floor(damage / 8))
    @battle.message "#{user.name} restored some of its HP using its #{@displayName}!"

makeTypeResistBerry 'Shuca Berry', 'Ground'
makeTypeBoostItem 'Silk Scarf', 'Normal'
makeTypeBoostItem 'SilverPowder', 'Bug'
makeHealingBerry 'Sitrus Berry', (owner) -> Math.floor(owner.stat('hp') / 4)
makePlateItem 'Sky Plate', 'Flying'
makeWeatherItem 'Smooth Rock', Weather.SAND
makeTypeBoostItem 'Soft Sand', 'Ground'
makeSpeciesBoostingItem 'Soul Dew', ["Latias", "Latios"],
  specialAttack: 1.5, specialDefense: 1.5
makeTypeBoostItem 'Spell Tag', 'Ghost'
makePlateItem 'Splash Plate', 'Water'
makePlateItem 'Spooky Plate', 'Ghost'

# TODO: If there is no stat left to boost, is it still consumed?
makePinchBerry 'Starf Berry', (battle, eater) ->
  stats = ["attack", "defense", "specialAttack", "specialDefense", "speed"]
  stats = stats.filter((stat) -> eater.stages[stat] != 6)
  return  if stats.length == 0
  index = battle.rng.randInt(0, stats.length - 1, "starf berry stat")
  boosts = {}
  boosts[stats[index]] = 2
  boostedStats = eater.boost(boosts)

makeItem 'Sticky Barb', ->
  this::afterBeingHit = (move, user, target) ->
    return  unless move.hasFlag("contact")
    return  if user.hasItem()
    user.setItem(@constructor)
    target.useItem()

  this::endTurn = ->
    @pokemon.damage(Math.floor(@pokemon.stat('hp') / 8))

makeGemItem 'Steel Gem', 'Steel'
makePlateItem 'Stone Plate', 'Rock'
makeTypeResistBerry 'Tanga Berry', 'Bug'
makeStatusOrbItem 'Toxic Orb', Status.Toxic
makePlateItem 'Toxic Plate', 'Poison'
makeTypeBoostItem 'TwistedSpoon', 'Psychic'
makeTypeResistBerry 'Wacan Berry', 'Electric'
makeGemItem 'Water Gem', 'Water'
makeTypeBoostItem 'Wave Incense', 'Water'

# TODO: What if White Herb is tricked onto a Pokemon? Are all boosts negated?
makeItem 'White Herb', ->
  this.activate = (battle, pokemon) ->
    triggered = false
    boosts = {}
    for stat, boost of pokemon.stages
      if boost < 0
        triggered = true
        boosts[stat] = 0
    if triggered
      pokemon.setBoosts(boosts)
      battle.cannedText('WHITE_HERB', pokemon)
    return triggered

  this::update = ->
    if @constructor.activate(@battle, @pokemon)
      @pokemon.useItem()

makeItem "Wide Lens", ->
  this::editAccuracy = (accuracy) ->
    Math.floor(accuracy * 1.1)

makeFlavorHealingBerry 'Wiki Berry', "specialAttack"

makeItem 'Wise Glasses', ->
  this::modifyBasePower = (move, target) ->
    if move.isSpecial()
      0x1199
    else
      0x1000

makeTypeResistBerry 'Yache Berry', 'Ice'
makePlateItem 'Zap Plate', 'Electric'

makeItem 'Zoom Lens', ->
  this::editAccuracy = (accuracy, move, target) ->
    return Math.floor(accuracy * 1.2)  if @battle.willMove(target)
    return accuracy

makeSpeciesBoostingItem("DeepSeaTooth", ["Clamperl"], specialAttack: 2)
makeSpeciesBoostingItem("DeepSeaScale", ["Clamperl"], specialDefense: 2)
makeSpeciesBoostingItem("Light Ball", ["Pikachu"], attack: 2, specialAttack: 2)
makeSpeciesBoostingItem("Thick Club", ["Cubone", "Marowak"], attack: 2)
makeSpeciesBoostingItem("Metal Powder", ["Ditto"],
  defense: 2, specialDefense: 2)
makeSpeciesBoostingItem("Quick Powder", ["Ditto"], speed: 2)

makeSpeciesCriticalItem "Lucky Punch", "Chansey"
makeSpeciesCriticalItem "Stick", "Farfetch'd"

makeCriticalBoostItem 'Razor Claw'
makeCriticalBoostItem 'Scope Lens'

makeItem 'Iron Ball', ->
  this::editSpeed = (stat) ->
    Math.floor(stat / 2)

  this::isImmune = (type) ->
    return false  if type == 'Ground'

makeItem 'Leppa Berry', ->
  this.eat = (battle, eater) ->
    for move in eater.moves
      if eater.pp(move) == 0
        eater.setPP(move, 10)
        break

  this::update = ->
    if @pokemon.lastMove? && @pokemon.pp(@pokemon.lastMove) == 0
      @constructor.eat(@battle, @pokemon)
      @pokemon.useItem()

# TODO: Implement Nature Power and implement eat there.
for berry in "Belue Berry, Bluk Berry, Cornn Berry, Durin Berry, Grepa Berry,
              Hondew Berry, Kelpsy Berry, Magost Berry, Nanab Berry,
              Nomel Berry, Pamtre Berry, Pinap Berry, Pomeg Berry, Qualot Berry,
              Rabuta Berry, Razz Berry, Spelon Berry, Tamato Berry,
              Watmel Berry, Wepear Berry".split(/,\s+/)
  makeItem berry, ->
    this.eat = ->

# Ensure we aren't purposefully missing berries that need an `eat` function.
for name, item of Item
  if item.type == 'berries' && 'eat' not of item
    console.warn "Note: Item '#{item.displayName}' does not have `eat` implemented."

# Make all leftover items
for itemName of ItemData
  makeItem(itemName)  if itemName.replace(/\s+/, '') not of Item
