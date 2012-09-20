@items = items = {}

json = require './data_items.json'

class Item
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

  endTurn: (pokemon) =>

  basePowerModifier: (move, battle, user, target) ->
    0x1000

extendItem = (name, callback) ->
  if name not of items
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")

  item = items[name]
  callback.call(item)

for name, attributes of json
  items[name] = new Item(name, attributes)

extendItem 'Leftovers', ->
  @endTurn = (battle, user) ->
    battle.message "#{user.name} restored a little HP using its #{@name}!"
    amount = Math.floor(user.stat('hp') / 16)
    amount = 1  if amount == 0
    user.damage(-amount)

extendItem 'Muscle Band', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.spectra == 'physical'
      0x1199
    else
      0x1000

extendItem 'Wise Glasses', ->
  @basePowerModifier = (move, battle, user, target) ->
    if move.spectra == 'special'
      0x1199
    else
      0x1000
