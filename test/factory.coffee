{_} = require 'underscore'

factories = {}

@Factory = Factory = (name, attributes={}) ->
  if name not of factories
    Factory.register(name)
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

Factory.register 'Corphish',
  moves: ['Trump Card', "Crunch", "Round"]

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
  moves: ['Brave Bird', 'Aerial Ace']

Factory.register 'Celebi',
  moves: ['Leaf Storm', 'Grass Knot']

Factory.register 'Weezing',
  moves: ['Haze', 'Psywave']

Factory.register 'Blissey',
  moves: ['Seismic Toss', 'Aromatherapy', 'Thunder Wave', 'Softboiled']

Factory.register 'Zangoose',
  moves: ['Facade', 'Flail']

Factory.register 'Forretress',
  moves: ['Gyro Ball', 'Rapid Spin']

Factory.register 'Electrode',
  moves: ['Gyro Ball', 'Explosion']

Factory.register 'Camerupt',
  moves: ['Eruption', 'Yawn', 'Earthquake']

Factory.register 'Empoleon',
  moves: ['Brine']

Factory.register 'Lapras',
  moves: ['Sheer Cold']

Factory.register 'Audino',
  moves: ['Growl']

Factory.register 'Gengar',
  moves: ['Shadow Ball', 'Pain Split', 'Explosion', 'Clear Smog']

Factory.register 'Drapion',
  moves: ['Knock Off', 'Swords Dance']

Factory.register 'Alakazam',
  moves: ['Trick']

Factory.register 'Gastrodon (east)',
  moves: ['Recover']
  ability: 'Sticky Hold'

Factory.register 'Latias',
  moves: ['Memento']

Factory.register 'Poliwrath',
  moves: ['Belly Drum']

Factory.register 'Shuckle',
  moves: ['Acupressure']

Factory.register 'Dratini',
  moves: ['Dragon Rage']

Factory.register 'Politoed',
  moves: ['Perish Song', 'Endeavor']
  ability: 'Drizzle'

Factory.register 'Dugtrio',
  moves: ['Magnitude', 'Dig']

Factory.register 'Regirock',
  moves: ['Rock Slide']

Factory.register 'Shaymin (land)',
  moves: ['Seed Flare']

Factory.register 'Ditto',
  moves: ['Transform']
