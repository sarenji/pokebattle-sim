{_} = require 'underscore'

factories = {}

@Factory = Factory = (name, attributes={}) ->
  if name not of factories
    throw new Error("No Factory with name '#{name}' registered.")
  cloned = _.clone(factories[name])
  _.extend(cloned, attributes)

Factory.register = (name, attributes={}) ->
  cloned = _.clone(attributes)
  _.defaults(cloned, name: name)
  factories[name] = cloned

Factory.register 'Hitmonchan',
  ability: 'Technician'
  moves: ['Ice Punch', 'Mach Punch', 'Bullet Punch', 'ThunderPunch' ]
  evs: {attack: 252}

Factory.register 'Hitmonlee',
  moves: ['Hi Jump Kick']

Factory.register 'Mew',
  ability: 'Synchronize'
  moves: ['Psychic', 'AncientPower']

Factory.register 'Porygon-Z',
  ability: 'Adaptability'
  moves: ['Tri Attack', 'Flamethrower']
  evs: {specialAttack: 252}

Factory.register 'Heracross',
  ability: 'Guts'
  moves: ['Megahorn']
  evs: {attack: 252}

Factory.register 'Magikarp',
  moves: ['Splash', 'Tackle']

Factory.register 'Gyarados',
  moves: ['Dragon Dance', 'Ice Fang']

Factory.register 'Conkeldurr',
  moves: ['Drain Punch']

Factory.register 'Gliscor',
  moves: ['Acrobatics']

Factory.register 'Blaziken',
  moves: ['Brave Bird']

Factory.register 'Celebi',
  moves: ['Leaf Storm']

Factory.register 'Regirock'
Factory.register 'Shaymin (land)'
