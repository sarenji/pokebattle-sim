@items = items = {}

json = require './data_items.json'

class Item
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

  endTurn: (pokemon) =>

  afterSuccessfulHit: (battle, user, target, damage, move) ->
  basePowerModifier: (move, battle, user, target) ->
    0x1000

extendItem = (name, callback) ->
  if name not of items
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")

  item = items[name]
  callback.call(item)

makeOrbItem = (name, species) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if user.species == species && move.type in user.types
        0x1333
      else
        0x1000

makeTypeBoostItem = (name, type) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if move.type == type
        0x1333
      else
        0x1000

# Gem items are one-time use.
makeGemItem = (name, type) ->
  extendItem name, ->
    @basePowerModifier = (move, battle, user, target) ->
      if move.type == type
        0x1800
      else
        0x1000

    @afterSuccessfulHit = (battle, user, target, damage, move) ->
      battle.message "The #{@name} strengthened #{move.name}'s power!"
      user.item = null


for name, attributes of json
  items[name] = new Item(name, attributes)


makeOrbItem 'Adamant Orb', 'Dialga'
makeTypeBoostItem 'Black Belt', 'Fighting'
makeTypeBoostItem 'BlackGlasses', 'Dark'
makeGemItem 'Bug Gem', 'Bug'
makeTypeBoostItem 'Charcoal', 'Fire'
makeGemItem 'Dark Gem', 'Dark'
makeTypeBoostItem 'Dragon Fang', 'Dragon'
makeGemItem 'Dragon Gem', 'Dragon'
makeGemItem 'Electric Gem', 'Electric'
makeGemItem 'Fighting Gem', 'Fighting'
makeGemItem 'Fire Gem', 'Fire'
makeGemItem 'Flying Gem', 'Flying'
makeGemItem 'Ghost Gem', 'Ghost'
makeGemItem 'Grass Gem', 'Grass'
makeOrbItem 'Griseous Orb', 'Giratina'
makeGemItem 'Ground Gem', 'Ground'
makeTypeBoostItem 'Hard Stone', 'Rock'
makeGemItem 'Ice Gem', 'Ice'

extendItem 'Leftovers', ->
  @endTurn = (battle, user) ->
    battle.message "#{user.name} restored a little HP using its #{@name}!"
    amount = Math.floor(user.stat('hp') / 16)
    amount = 1  if amount == 0
    user.damage(-amount)

makeOrbItem 'Lustrous Orb', 'Palkia'
makeTypeBoostItem 'Magnet', 'Electric'
makeTypeBoostItem 'Metal Coat', 'Steel'
makeTypeBoostItem 'Miracle Seed', 'Grass'

extendItem 'Muscle Band', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.spectra == 'physical'
      0x1199
    else
      0x1000

makeTypeBoostItem 'Mystic Water', 'Water'
makeTypeBoostItem 'NeverMeltIce', 'Ice'
makeGemItem 'Normal Gem', 'Normal'
makeTypeBoostItem 'Odd Incense', 'Psychic'
makeTypeBoostItem 'Poison Barb', 'Poison'
makeGemItem 'Poison Gem', 'Poison'
makeGemItem 'Psychic Gem', 'Psychic'
makeGemItem 'Rock Gem', 'Rock'
makeTypeBoostItem 'Rock Incense', 'Rock'
makeTypeBoostItem 'Rose Incense', 'Grass'
makeTypeBoostItem 'Sea Incense', 'Water'
makeTypeBoostItem 'Sharp Beak', 'Flying'
makeTypeBoostItem 'Silk Scarf', 'Normal'
makeTypeBoostItem 'SilverPowder', 'Bug'
makeTypeBoostItem 'Soft Sand', 'Ground'
makeTypeBoostItem 'Spell Tag', 'Ghost'
makeGemItem 'Steel Gem', 'Steel'
makeTypeBoostItem 'TwistedSpoon', 'Psychic'
makeGemItem 'Water Gem', 'Water'
makeTypeBoostItem 'Wave Incense', 'Water'

extendItem 'Wise Glasses', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.spectra == 'special'
      0x1199
    else
      0x1000
