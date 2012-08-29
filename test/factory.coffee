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

Factory.register 'Mew',
  ability: 'Synchronize'
  moves: ['Psychic']

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

Factory.register 'Regirock'
Factory.register 'Shaymin (land)'
