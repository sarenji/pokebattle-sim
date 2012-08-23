@items = items = {}

class Item
  constructor: (name, attributes) ->
    @name = name
    for key, value of attributes
      @[key] = value

makeItem = (name, attributes) ->
  items[name] = new Item(name, attributes)

makeItem 'Leftovers', {
  residualDamage: (pokemon) ->
    amount = Math.floor(pokemon.stat('hp') / 16)
    amount = 1  if amount == 0
    pokemon.damage(-amount)
}

# TODO: Add hook to CH level.
makeItem 'Stick', {}
makeItem 'Lucky Punch', {}
makeItem 'Razor Claw', {}
