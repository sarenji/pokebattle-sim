@items = items = {}

json = require './data_items.json'

class Item
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

  endTurn: (pokemon) =>

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
