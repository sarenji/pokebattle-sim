@Items = Items = {}

json = require './data_items.json'
{Attachment} = require('../../server/attachment')
{Status} = require('../../server/status')
{Weather} = require '../../server/weather'
util = require '../../server/util'

class Item
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

  # Items are initialized when the Pokemon receives a new item or switches in.
  initialize: (battle, pokemon) ->
  # Items get deactivated when switching out or when this item is replaced.
  deactivate: (pokemon) ->
  afterTurnOrder: (battle, pokemon) ->
  endTurn: (battle, pokemon) ->
  afterSuccessfulHit: (battle, move, user, target, damage) ->
  afterBeingHit: (battle, move, user, target, damage) ->
  basePowerModifier: (move, battle, user, target) ->
    0x1000
  basePowerModifierTarget: (move, battle, user, target) ->
    0x1000
  calculateWeight: (weight) -> weight
  editDamage: (battle, holder, move, damage) -> damage
  update: (battle, owner) ->
  criticalModifier: (battle, owner) ->

  # Stat modifications
  # TODO: Consider subclassing from Attachment
  editHp: (stat, pokemon) -> stat
  editSpeed: (stat, pokemon) -> stat
  editSpecialAttack: (stat, pokemon) -> stat
  editDefense: (stat, pokemon) -> stat
  editSpecialDefense: (stat, pokemon) -> stat

extendItem = (name, callback) ->
  if name not of Items
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")

  item = Items[name]
  callback.call(item)

makePinchBerry = (name, hookName, func) ->
  if !func?
    func = hookName
    hookName = "update"

  extendItem name, ->
    @eat = (battle, owner) ->
      func.call(this, battle, owner)

    @[hookName] = (battle, owner) ->
      amount       = (if owner.hasAbility("Gluttony") then 1 else 2)
      activationHP = owner.stat('hp') >> amount
      if owner.currentHP <= activationHP
        @eat(battle, owner)
        owner.useItem()

# TODO: If the stat is maxed, does anything special happen?
#       Is the berry still consumed?
makeStatBoostBerry = (name, boosts) ->
  makePinchBerry name, (battle, owner) ->
    boostedStats = owner.boost(boosts)
    util.printBoostMessage(battle, owner, boostedStats, boosts)

makeFlavorHealingBerry = (name, stat) ->
  extendItem name, ->
    @eat = (battle, owner) ->
      # TODO: Replace with the real battle message.
      battle.message "#{owner.name}'s #{name} restored its HP a little!"
      owner.damage(-Math.floor(owner.stat('hp') / 8))
      if owner.natureBoost(stat) < 1.0
        # TODO: Replace with the real battle message.
        battle.message "The #{name} was bitter!"
        owner.attach(Attachment.Confusion, {battle})

    @update = (battle, owner) ->
      if owner.currentHP <= Math.floor(owner.stat('hp') / 2)
        @eat(battle, owner)
        owner.useItem()

makeHealingBerry = (name, func) ->
  extendItem name, ->
    @eat = (battle, owner) ->
      # TODO: Replace with the real battle message.
      battle.message "#{owner.name}'s #{name} restored its HP a little!"
      owner.damage(-func(owner))

    @update = (battle, owner) ->
      if owner.currentHP <= Math.floor(owner.stat('hp') / 2)
        @eat(battle, owner)
        owner.useItem()

makeTypeResistBerry = (name, type) ->
  extendItem name, ->
    @eat = ->
    @basePowerModifierTarget = (move, battle, user, target) ->
      return 0x1000  if move.type != type
      return 0x1000  if util.typeEffectiveness(type, target.types) <= 1 && type != 'Normal'
      battle.message "The #{name} weakened the damage to #{target.name}!"
      target.useItem()
      return 0x800

makeFeedbackDamageBerry = (name, klass) ->
  extendItem name, ->
    @eat = ->
    @afterBeingHit = (battle, move, user, target, damage) ->
      return  if !move[klass]()
      return  if target.isFainted()
      # TODO: Real message.
      battle.message "The #{name} hurt #{user.name}!"
      user.damage(Math.floor(user.stat('hp') / 8))
      target.useItem()

makeStatusCureBerry = (name, statuses...) ->
  extendItem name, ->
    @eat = (battle, owner) ->
      removed = false
      for attachment in statuses
        if owner.has(attachment)
          owner.unattach(attachment)
          removed = true
      return removed

    @update = (battle, owner) ->
      if @eat(battle, owner) then owner.useItem()

makeOrbItem = (name, species) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if user.species == species && move.type in user.types
        0x1333
      else
        0x1000

makeStatusOrbItem = (name, status) ->
  extendItem name, ->
    @endTurn = (battle, pokemon) ->
      pokemon.attach(status)

makeTypeBoostItem = (name, type) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if move.type == type
        0x1333
      else
        0x1000

# Same as makeTypeBoostItem, but sets item.plate = type.
makePlateItem = (name, type) ->
  makeTypeBoostItem(name, type)
  extendItem(name, -> @plate = type)

# Gem items are one-time use.
makeGemItem = (name, type) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if move.type == type
        0x1800
      else
        0x1000

    @afterSuccessfulHit = (battle, move, user, target, damage) ->
      if move.type == type
        battle.message "The #{@name} strengthened #{move.name}'s power!"
        user.item = null

makeChoiceItem = (name) ->
  extendItem name, ->
    @initialize = (battle, pokemon) ->
      pokemon.attach(Attachment.ChoiceLock)

    @deactivate = (pokemon) ->
      pokemon.unattach(Attachment.ChoiceLock)

makeWeatherItem = (name, weather) ->
  extendItem name, ->
    @lengthensWeather = weather

makeSpeciesBoostingItem = (name, speciesArray, statsHash) ->
  extendItem name, ->
    for stat, boost of statsHash
      capitalizedStat = stat[0].toUpperCase() + stat.substr(1)
      this["edit#{capitalizedStat}"] = (stat, pokemon) ->
        if pokemon.species in speciesArray
          Math.floor(stat * boost)
        else
          stat

makeSpeciesCriticalItem = (name, species) ->
  extendItem name, ->
    @criticalModifier = (battle, owner) ->
      if owner.species == species
        2
      else
        0

makeDelayItem = (name) ->
  extendItem name, ->
    @afterTurnOrder = (battle, pokemon) ->
      battle.delay(pokemon)

makeEvasionItem = (name, ratio=0.9) ->
  extendItem name, ->
    @initialize = (battle, pokemon) ->
      pokemon.attach(Attachment.EvasionItem, {ratio})

    @deactivate = (pokemon) ->
      pokemon.unattach(Attachment.EvasionItem)

makeFlinchItem = (name) ->
  extendItem name, ->
    @afterSuccessfulHit = (battle, move, user, target, damage) ->
      if move.flinchChance == 0 && !move.isNonDamaging() &&
          battle.rng.next("flinch item chance") < .1
        target.attach(Attachment.Flinch)

makeCriticalBoostItem = (name) ->
  extendItem name, ->
    @criticalModifier = (battle, owner) -> 1

makeBoostOnTypeItem = (name, type, boosts) ->
  stats = Object.keys(boosts)
  length = stats.length
  stats = stats.map (stat) ->
    stat[0].toUpperCase() + stat[1...length].replace(/[A-Z]/g, " $1")
  stats[length - 1] = "and #{stats[length - 1]}"  if length >= 2
  stats = stats.join(", ")  if length >= 3
  stats = stats.join(" ")   if length == 2
  extendItem name, ->
    @afterBeingHit = (battle, move, user, target, damage) ->
      if move.type == type
        battle.message "#{user.name}'s #{@name} made its #{stats} rise!"
        target.boost(boosts)
        target.useItem()

for name, attributes of json
  Items[name] = new Item(name, attributes)

makeBoostOnTypeItem 'Absorb Bulb', 'Water', specialAttack: 1

makeOrbItem 'Adamant Orb', 'Dialga'
makeFlavorHealingBerry 'Aguav Berry', "specialDefense"

extendItem 'Air Balloon', ->
  @initialize = (battle, pokemon) ->
    battle.message "#{pokemon.name} floats in the air with its #{@name}!"
    pokemon.attach(Attachment.AirBalloon)

  @deactivate = (pokemon) ->
    pokemon.unattach(Attachment.AirBalloon)

makeStatBoostBerry 'Apicot Berry', specialDefense: 1
makeStatusCureBerry 'Aspear Berry', Status.Freeze
makeTypeResistBerry 'Babiri Berry', 'Steel'
makeHealingBerry 'Berry Juice', -> 20
makeTypeBoostItem 'Black Belt', 'Fighting'
makeTypeBoostItem 'BlackGlasses', 'Dark'

extendItem 'Black Sludge', ->
  @endTurn = (battle, user) ->
    maxHP = user.stat('hp')
    amount = Math.floor(maxHP / 16)
    amount = 1  if amount == 0
    if user.hasType('Poison')
      return  if maxHP == user.currentHP
      battle.message "#{user.name} restored a little HP using its #{@name}!"
      user.damage(-amount)
    else
      battle.message "#{user.name} is hurt by its #{@name}!"
      user.damage(amount)

makeEvasionItem 'BrightPowder', 0.9
makeGemItem 'Bug Gem', 'Bug'
makeBoostOnTypeItem 'Cell Battery', 'Electric', attack: 1
makeTypeBoostItem 'Charcoal', 'Fire'
makeTypeResistBerry 'Charti Berry', 'Rock'
makeStatusCureBerry 'Cheri Berry', Status.Paralyze
makeStatusCureBerry 'Chesto Berry', Status.Sleep
makeTypeResistBerry 'Chilan Berry', 'Normal'
makeChoiceItem 'Choice Band'
makeChoiceItem 'Choice Specs'
makeChoiceItem 'Choice Scarf'

extendItem 'Choice Scarf', ->
  @editSpeed = (stat) ->
    Math.floor(stat * 1.5)

makeTypeResistBerry 'Chople Berry', 'Fighting'
makeTypeResistBerry 'Coba Berry', 'Flying'
makeTypeResistBerry 'Colbur Berry', 'Dark'

makePinchBerry 'Custap Berry', 'afterTurnOrder', (battle, owner) ->
  battle.bump(owner)

makeWeatherItem 'Damp Rock', Weather.RAIN
makeGemItem 'Dark Gem', 'Dark'
makeTypeBoostItem 'Dragon Fang', 'Dragon'
makeGemItem 'Dragon Gem', 'Dragon'
makePlateItem 'Draco Plate', 'Dragon'
makePlateItem 'Dread Plate', 'Dark'
makePlateItem 'Earth Plate', 'Ground'

extendItem 'Eject Button', ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    return  if move.isNonDamaging()
    target.useItem()
    self = battle.getOwner(target)
    switches = self.team.getAliveBenchedPokemon()
    battle.requestAction(self, switches: switches)

makeGemItem 'Electric Gem', 'Electric'

extendItem 'Enigma Berry', ->
  @eat = ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    return  if util.typeEffectiveness(move.type, target.types) <= 1
    # TODO: real message
    battle.message "The #{name} restored #{target.name}'s HP a little!"
    target.damage(-Math.floor(target.stat('hp') / 4))
    target.useItem()

makeGemItem 'Fighting Gem', 'Fighting'
makeFlavorHealingBerry 'Figy Berry', "attack"
makeGemItem 'Fire Gem', 'Fire'
makePlateItem 'Fist Plate', 'Fighting'
makeStatusOrbItem 'Flame Orb', Status.Burn
makePlateItem 'Flame Plate', 'Fire'
extendItem 'Float Stone', ->
  @calculateWeight = (weight) ->
    Math.floor(weight / 2)
makeGemItem 'Flying Gem', 'Flying'

extendItem 'Focus Band', ->
  @editDamage = (battle, holder, move, damage) ->
    if damage >= holder.currentHP && battle.rng.randInt(0, 9, "focus band") == 0
      battle.message "#{holder.name} hung on using its #{@name}!"
      holder.useItem()
      return holder.currentHP - 1
    return damage

extendItem 'Focus Sash', ->
  @editDamage = (battle, holder, move, damage) ->
    maxHP = holder.stat('hp')
    if holder.currentHP == maxHP && damage >= maxHP
      battle.message "#{holder.name} hung on using its #{@name}!"
      holder.useItem()
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
makePinchBerry 'Lansat Berry', (battle, owner) ->
  owner.attach(Attachment.FocusEnergy)

makeEvasionItem 'Lax Incense', 0.9

extendItem 'Leftovers', ->
  @endTurn = (battle, user) ->
    maxHP = user.stat('hp')
    return  if maxHP == user.currentHP
    battle.message "#{user.name} restored a little HP using its #{@name}!"
    amount = Math.floor(maxHP / 16)
    amount = 1  if amount == 0
    user.damage(-amount)

makeStatBoostBerry 'Liechi Berry', attack: 1
extendItem 'Life Orb', ->
  @afterSuccessfulHit = (battle, move, user, target, damage) ->
    return  if move.isNonDamaging()
    user.damage(Math.floor(user.stat('hp') / 10))

makeStatusCureBerry 'Lum Berry', Status.Paralyze, Status.Sleep, Status.Poison,
  Status.Toxic, Status.Burn, Status.Freeze, Attachment.Confusion
makeOrbItem 'Lustrous Orb', 'Palkia'
extendItem 'Macho Brace', ->
  @editSpeed = (stat, pokemon) ->
    Math.floor(stat / 2)
makeTypeBoostItem 'Magnet', 'Electric'
makeFlavorHealingBerry 'Mago Berry', "speed"
makePlateItem 'Meadow Plate', 'Grass'

extendItem 'Mental Herb', ->
  @activate = (battle, owner) ->
    for effectName in [ 'Attract', 'Taunt', 'Encore', 'Torment', 'Disable' ]
      attachment = Attachment[effectName]
      if owner.has(attachment)
        owner.unattach(attachment)
        return true
    return false

  @update = (battle, owner) ->
    if @activate(battle, owner)
      owner.useItem()

makeTypeBoostItem 'Metal Coat', 'Steel'

extendItem 'Metronome', ->
  @basePowerModifier = (move, battle, user, target) ->
    attachment = user.get(Attachment.Metronome)
    layers = attachment?.layers || 0
    0x1000 + layers * 0x333

  @afterSuccessfulHit = (battle, move, user, target) ->
    user.attach(Attachment.Metronome, {move})

makePinchBerry 'Micle Berry', (battle, owner) ->
  owner.attach(Attachment.MicleBerry)

makePlateItem 'Mind Plate', 'Psychic'
makeTypeBoostItem 'Miracle Seed', 'Grass'

extendItem 'Muscle Band', ->
  @basePowerModifier = (move, battle, user, target) ->
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

extendItem 'Quick Claw', ->
  @afterTurnOrder = (battle, owner) ->
    battle.bump(owner)  if battle.rng.next("quick claw") < .2

makeStatusCureBerry 'Rawst Berry', Status.Burn
makeFlinchItem "Razor Fang"

extendItem 'Red Card', ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    return  if move.isNonDamaging()
    opponent = battle.getOwner(user)
    benched  = opponent.team.getAliveBenchedPokemon()
    # return  if benched.length == 0
    pokemon = battle.rng.choice(benched)
    index = opponent.team.indexOf(pokemon)
    opponent.switch(battle, 0, index)
    target.useItem()

makeTypeResistBerry 'Rindo Berry', 'Grass'
makeGemItem 'Rock Gem', 'Rock'

extendItem 'Rocky Helmet', ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    if move.hasFlag("contact")
      battle.message "#{user.name} was hurt by the #{@name}!"
      amount = Math.floor(user.stat('hp') / 6)
      user.damage(amount)

makeTypeBoostItem 'Rock Incense', 'Rock'
makeTypeBoostItem 'Rose Incense', 'Grass'
makeFeedbackDamageBerry 'Rowap Berry', 'isSpecial'
makeStatBoostBerry 'Salac Berry', speed: 1
makeTypeBoostItem 'Sea Incense', 'Water'
makeTypeBoostItem 'Sharp Beak', 'Flying'

extendItem 'Shell Bell', ->
  @afterSuccessfulHit = (battle, move, user, target, damage) ->
    # TODO: Does Shell Bell display a message if the Pokemon is at full HP?
    return  if damage == 0
    user.damage -Math.floor(damage / 8)
    battle.message "#{user.name} restored some of its HP using its #{@name}!"

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
makePinchBerry 'Starf Berry', (battle, owner) ->
  stats = ["attack", "defense", "specialAttack", "specialDefense", "speed"]
  stats = stats.filter((stat) -> owner.stages[stat] != 6)
  return  if stats.length == 0
  index = battle.rng.randInt(0, stats.length - 1, "starf berry stat")
  boosts = {}
  boosts[stats[index]] = 2
  boostedStats = owner.boost(boosts)
  util.printBoostMessage(battle, owner, boostedStats, boosts)

extendItem 'Sticky Barb', ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    return  unless move.hasFlag("contact")
    return  if user.hasItem()
    user.setItem(battle, this)
    target.useItem()

  @endTurn = (battle, pokemon) ->
    pokemon.damage Math.floor(pokemon.stat('hp') / 8)

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
extendItem 'White Herb', ->
  @activate = (battle, owner) ->
    triggered = false
    for stat, boost of owner.stages
      if boost < 0
        battle.message "#{owner.name} restored its status using its #{@name}!"
        triggered = true
        owner.stages[stat] = 0
    return triggered

  @update = (battle, owner) ->
    if @activate(battle, owner)
      owner.useItem()

extendItem "Wide Lens", ->
  @editAccuracy = (accuracy) ->
    Math.floor(accuracy * 1.1)

makeFlavorHealingBerry 'Wiki Berry', "specialAttack"

extendItem 'Wise Glasses', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.isSpecial()
      0x1199
    else
      0x1000

makeTypeResistBerry 'Yache Berry', 'Ice'
makePlateItem 'Zap Plate', 'Electric'

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

extendItem 'Iron Ball', ->
  @editSpeed = (stat, pokemon) ->
    Math.floor(stat / 2)

  @initialize = (battle, pokemon) ->
    pokemon.attach(Attachment.IronBall)

  @deactivate = (pokemon) ->
    pokemon.unattach(Attachment.IronBall)

extendItem 'Leppa Berry', ->
  @eat = (battle, owner) ->
    for move in owner.moves
      if owner.pp(move) == 0
        owner.setPP(move, 10)
        break

  @update = (battle, owner) ->
    if owner.lastMove? && owner.pp(owner.lastMove) == 0
      @eat(battle, owner)
      owner.useItem()

# TODO: Implement Nature Power and implement eat there.
for berry in "Belue Berry, Bluk Berry, Cornn Berry, Durin Berry, Grepa Berry,
              Hondew Berry, Kelpsy Berry, Magost Berry, Nanab Berry,
              Nomel Berry, Pamtre Berry, Pinap Berry, Pomeg Berry, Qualot Berry,
              Rabuta Berry, Razz Berry, Spelon Berry, Tamato Berry,
              Watmel Berry, Wepear Berry".split(/,\s+/)
  Items[berry].eat = ->

# Ensure we aren't purposefully missing berries that need an `eat` function.
for name, item of Items
  if item.type == 'berries' && 'eat' not of item
    console.warn """Note: Item "#{name}" does not have `eat` implemented."""
