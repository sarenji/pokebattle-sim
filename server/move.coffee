class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @priority = attributes.priority || 0
    @power = attributes.power
    @type = attributes.type || '???'
    @spectra = attributes.damage || '???'

  # Executes the move on the target. Target may be null
  # if the move attacks all opponents
  execute: (battle, user, target) =>
    damage = @baseDamage(user, target)
    damage = Math.round((@stab(user) * damage) / 0x1000)
    damage = Math.floor(((100 - battle.randInt(0, 15)) * damage) / 100)
    damage = Math.max(damage, 1)
    battle.damage(user, target, damage)

  stab: (user) =>
    # TODO: Apply ability STAB modifier, if applicable.
    if user.hasType(@type)
      0x1800
    else
      0x1000

  baseDamage: (attacker, defender) =>
    floor = Math.floor
    baseDamage = floor((2 * attacker.level) / 5 + 2)
    # TODO: Apply variable base power
    baseDamage *= @power
    baseDamage *= attacker.stat(whichAttackStat(@spectra))
    baseDamage = floor(baseDamage / defender.stat(whichDefenseStat(@spectra)))
    baseDamage += 2


whichAttackStat = (spectra) ->
  spectra == 'physical' ? 'attack' : 'special attack'

whichDefenseStat = (spectra) ->
  spectra == 'physical' ? 'defense' : 'special defense'
