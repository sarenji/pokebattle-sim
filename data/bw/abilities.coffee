@Abilities = Abilities = {}

class Ability
  constructor: (name, attributes={}) ->
    @name = name
    for key, value of attributes
      @[key] = value

makeAbility = (name, attributes) ->
  Abilities[name] = new Ability(name, attributes)

makeAbility 'Technician'
makeAbility 'Guts'
makeAbility 'Flare Boost'
makeAbility 'Analytic'
makeAbility 'Reckless'
makeAbility 'Iron Fist'
makeAbility 'Toxic Boost'
makeAbility 'Rivalry'
makeAbility 'Sand Force'
makeAbility 'Heatproof'
makeAbility 'Dry Skin'
makeAbility 'Sheer Force'

# TODO: Add hook to CH level.
makeAbility 'Super Luck'
makeAbility 'Battle Armor'
makeAbility 'Shell Armor'

makeAbility 'Tinted Lens'
makeAbility 'Sniper'

makeAbility 'Adaptability'

makeAbility 'Sticky Hold'
makeAbility 'Multitype'
makeAbility 'Damp'
