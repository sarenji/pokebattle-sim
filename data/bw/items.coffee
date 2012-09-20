@items = items = {}

json = require './data_items.json'

class Item
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

extendItem = (name, callback) ->
  if name not of items
    throw new Error("Cannot extend Item '#{name}' because it does not exist.")

  item = items[name]
  callback.call(item)

for name, attributes of json
  items[name] = new Item(name, attributes)

extendItem 'Leftovers', ->
  @residualDamage = (pokemon) ->
    amount = Math.floor(pokemon.stat('hp') / 16)
    amount = 1  if amount == 0
    pokemon.damage(-amount)
