@items = items = {}

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
  initialize: (battle, pokemon) =>
  # Items get deactivated when switching out or when this item is replaced.
  deactivate: (pokemon) =>
  endTurn: (battle, pokemon) =>
  afterSuccessfulHit: (battle, move, user, target, damage) ->
  afterBeingHit: (battle, move, user, target, damage) ->
  basePowerModifier: (move, battle, user, target) ->
    0x1000
  basePowerModifierTarget: (move, battle, user, target) ->
    0x1000
  calculateWeight: (weight) => weight
  editDamage: (battle, holder, move, damage) => damage
  update: (battle, owner) =>

  # Stat modifications
  # TODO: Consider subclassing from Attachment
  modifyHp: (stat) => stat
  modifySpeed: (stat) => stat
  modifyAccuracy: (stat) => stat
  modifyEvasion: (stat) => stat
  modifyAttack: (stat) => stat
  modifySpecialAttack: (stat) => stat
  modifyDefense: (stat) => stat
  modifySpecialDefense: (stat) => stat

extendItem = (name, callback) ->
  if name not of items
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")

  item = items[name]
  callback.call(item)

makePinchBerry = (name, func) ->
  extendItem name, ->
    @eat = (battle, owner) ->
      func.call(this, battle, owner)
      owner.removeItem()

    @update = (battle, owner) ->
      if owner.currentHP <= Math.floor(owner.stat('hp') / 4)
        @eat(battle, owner)

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
        owner.attach(new Attachment.Confusion({battle}))
      owner.removeItem()

    @update = (battle, owner) ->
      if owner.currentHP <= Math.floor(owner.stat('hp') / 2)
        @eat(battle, owner)

makeHealingBerry = (name, func) ->
  extendItem name, ->
    @eat = (battle, owner) ->
      # TODO: Replace with the real battle message.
      battle.message "#{owner.name}'s #{name} restored its HP a little!"
      owner.damage(-func(owner))
      owner.removeItem()

    @update = (battle, owner) ->
      if owner.currentHP <= Math.floor(owner.stat('hp') / 2)
        @eat(battle, owner)

makeTypeResistBerry = (name, type) ->
  extendItem name, ->
    @basePowerModifierTarget = (move, battle, user, target) ->
      return 0x1000  if move.type != type
      return 0x1000  if util.typeEffectiveness(type, target.types) <= 1 && type != 'Normal'
      battle.message "The #{name} weakened the damage to #{target.name}!"
      target.removeItem()
      return 0x800

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
      pokemon.setStatus(status)

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
      attachment = new Attachment.ChoiceLock()
      pokemon.attach(attachment)

    @deactivate = (pokemon) ->
      pokemon.unattach("ChoiceLockAttachment")

makeWeatherItem = (name, weather) ->
  extendItem name, ->
    @lengthensWeather = weather

for name, attributes of json
  items[name] = new Item(name, attributes)

extendItem 'Absorb Bulb', ->
  @afterBeingHit = (battle, move, user, target, damage) ->
    if move.type == 'Water'
      battle.message "#{user.name}'s Absorb Bulb made its Special Attack rise!"
      target.boost(specialAttack: 1)
      target.item = null

makeOrbItem 'Adamant Orb', 'Dialga'
makeFlavorHealingBerry 'Aguav Berry', "specialDefense"

extendItem 'Air Balloon', ->
  @initialize = (battle, pokemon) ->
    battle.message "#{pokemon.name} floats in the air with its #{@name}!"
    pokemon.attach(new Attachment.AirBalloon())

  @deactivate = (pokemon) ->
    pokemon.unattach("AirBalloonAttachment")

makeStatBoostBerry 'Apicot Berry', specialDefense: 1
makeTypeResistBerry 'Babiri Berry', 'Steel'
makeHealingBerry 'Berry Juice', -> 20
makeTypeBoostItem 'Black Belt', 'Fighting'
makeTypeBoostItem 'BlackGlasses', 'Dark'

extendItem 'Black Sludge', ->
  @endTurn = (battle, user) ->
    amount = Math.floor(user.stat('hp') / 16)
    amount = 1  if amount == 0
    if user.hasType('Poison')
      battle.message "#{user.name} restored a little HP using its #{@name}!"
      user.damage(-amount)
    else
      battle.message "#{user.name} is hurt by its #{@name}!"
      user.damage(amount)

makeGemItem 'Bug Gem', 'Bug'
makeTypeBoostItem 'Charcoal', 'Fire'
makeTypeResistBerry 'Charti Berry', 'Rock'
makeTypeResistBerry 'Chilan Berry', 'Normal'
makeChoiceItem 'Choice Band'
makeChoiceItem 'Choice Specs'
makeChoiceItem 'Choice Scarf'

extendItem 'Choice Scarf', ->
  @modifySpeed = (stat) ->
    Math.floor(stat * 1.5)

makeTypeResistBerry 'Chople Berry', 'Fighting'
makeTypeResistBerry 'Coba Berry', 'Flying'
makeTypeResistBerry 'Colbur Berry', 'Dark'
makeWeatherItem 'Damp Rock', Weather.RAIN
makeGemItem 'Dark Gem', 'Dark'
makeTypeBoostItem 'Dragon Fang', 'Dragon'
makeGemItem 'Dragon Gem', 'Dragon'
makePlateItem 'Draco Plate', 'Dragon'
makePlateItem 'Dread Plate', 'Dark'
makePlateItem 'Earth Plate', 'Ground'
makeGemItem 'Electric Gem', 'Electric'
makeGemItem 'Fighting Gem', 'Fighting'
makeFlavorHealingBerry 'Figy Berry', "attack"
makeGemItem 'Fire Gem', 'Fire'
makePlateItem 'Fist Plate', 'Fighting'
makeStatusOrbItem 'Flame Orb', Status.BURN
makePlateItem 'Flame Plate', 'Fire'
extendItem 'Float Stone', ->
  @calculateWeight = (weight) ->
    Math.floor(weight / 2)
makeGemItem 'Flying Gem', 'Flying'

extendItem 'Focus Sash', ->
  @editDamage = (battle, holder, move, damage) ->
    maxHP = holder.stat('hp')
    if holder.currentHP == maxHP && damage >= maxHP
      battle.message "#{holder.name} hung on using its #{@name}!"
      holder.item = null
      return maxHP - 1
    return damage

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
makeTypeResistBerry 'Kasib Berry', 'Ghost'
makeTypeResistBerry 'Kebia Berry', 'Poison'

extendItem 'Leftovers', ->
  @endTurn = (battle, user) ->
    battle.message "#{user.name} restored a little HP using its #{@name}!"
    amount = Math.floor(user.stat('hp') / 16)
    amount = 1  if amount == 0
    user.damage(-amount)

makeStatBoostBerry 'Liechi Berry', attack: 1
extendItem 'Life Orb', ->
  @afterSuccessfulHit = (battle, move, user, target, damage) ->
    return  if move.isNonDamaging()
    user.damage(Math.floor(user.stat('hp') / 10))

makeOrbItem 'Lustrous Orb', 'Palkia'
makeTypeBoostItem 'Magnet', 'Electric'
makeFlavorHealingBerry 'Mago Berry', "speed"
makePlateItem 'Meadow Plate', 'Grass'
makeTypeBoostItem 'Metal Coat', 'Steel'
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
makeStatBoostBerry 'Petaya Berry', specialAttack: 1
makeTypeBoostItem 'Poison Barb', 'Poison'
makeGemItem 'Poison Gem', 'Poison'
makeGemItem 'Psychic Gem', 'Psychic'
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
makeStatBoostBerry 'Salac Berry', speed: 1
makeTypeBoostItem 'Sea Incense', 'Water'
makeTypeBoostItem 'Sharp Beak', 'Flying'
makeTypeResistBerry 'Shuca Berry', 'Ground'
makeTypeBoostItem 'Silk Scarf', 'Normal'
makeTypeBoostItem 'SilverPowder', 'Bug'
makeHealingBerry 'Sitrus Berry', (owner) -> Math.floor(owner.stat('hp') / 4)
makePlateItem 'Sky Plate', 'Flying'
makeWeatherItem 'Smooth Rock', Weather.SAND
makeTypeBoostItem 'Soft Sand', 'Ground'
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

makeGemItem 'Steel Gem', 'Steel'
makePlateItem 'Stone Plate', 'Rock'
makeTypeResistBerry 'Tanga Berry', 'Bug'
makeStatusOrbItem 'Toxic Orb', Status.TOXIC
makePlateItem 'Toxic Plate', 'Poison'
makeTypeBoostItem 'TwistedSpoon', 'Psychic'
makeTypeResistBerry 'Wacan Berry', 'Electric'
makeGemItem 'Water Gem', 'Water'
makeTypeBoostItem 'Wave Incense', 'Water'

# TODO: What if White Herb is tricked onto a Pokemon? Are all boosts negated?
extendItem 'White Herb', ->
  @update = (battle, owner) ->
    shouldTrigger = false
    for stat, boost of owner.stages
      if boost < 0
        shouldTrigger = true
        owner.stages[stat] = 0

    if shouldTrigger
      owner.removeItem()
      battle.message "#{owner.name} restored its status using its #{@name}!"

makeFlavorHealingBerry 'Wiki Berry', "specialAttack"

extendItem 'Wise Glasses', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.isSpecial()
      0x1199
    else
      0x1000

makeTypeResistBerry 'Yache Berry', 'Ice'
makePlateItem 'Zap Plate', 'Electric'
