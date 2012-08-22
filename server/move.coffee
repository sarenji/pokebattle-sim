class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @priority = attributes.priority || 0
    @power = attributes.power
    @type = attributes.type || '???'
    @spectra = attributes.damage || '???'
    @chLevel = attributes.criticalHitLevel || 1

  # Executes the move on the target. Target may be null
  # if the move attacks all opponents
  execute: (battle, user, target) =>
    damage = @baseDamage(battle, user, target)
    # TODO: Multi-target modifier.
    damage = Math.round((@weatherModifier(battle) * damage) / 0x1000)
    damage = damage * 2  if @isCriticalHit(battle, user, target)
    damage = Math.floor(((100 - battle.rng.randInt(0, 15)) * damage) / 100)
    damage = Math.round((@stab(user) * damage) / 0x1000)
    damage = Math.floor(@typeEffectiveness(target) * damage)
    damage = Math.floor(@burnCalculation(user) * damage)
    damage = Math.max(damage, 1)
    # TODO: Final modifier.
    @damage(user, target, damage)
    # TODO: Print out opponent's name alongside the pokemon.
    battle.message "#{target.name} took #{damage} damage!"

  weatherModifier: (battle) =>
    if @type == 'Fire' and battle.hasWeather('Sunny')
      0x1800
    else if @type == 'Fire' and battle.hasWeather('Rainy')
      0x0800
    else if @type == 'Water' and battle.hasWeather('Rainy')
      0x1800
    else if @type == 'Water' and battle.hasWeather('Sunny')
      0x0800
    else
      0x1000

  stab: (user) =>
    # TODO: Apply ability STAB modifier, if applicable.
    if user.hasType(@type)
      0x1800
    else
      0x1000

  typeEffectiveness: (target) =>
    effectiveness = 1
    userType = Type[@type.toUpperCase()]
    for subtype in target.types
      targetType = Type[subtype.toUpperCase()]
      effectiveness *= typeChart[userType][targetType]
    effectiveness

  burnCalculation: (user) =>
    if @spectra == "physical" && !user.hasAbility("Guts")\
                              &&  user.hasStatus("Burn")
      .5
    else
      1

  basePower: =>
    @power

  isCriticalHit: (battle, attacker, defender) =>
    # TODO: Implement Lucky Chant.
    # TODO: Implement moves that always critical hit.
    if defender.hasAbility('Battle Armor') || defender.hasAbility('Shell Armor')
      return false

    rand = battle.rng.next()
    switch @criticalHitLevel(battle, attacker, defender)
      when 1
        rand < 0.0625
      when 2
        rand < 0.125
      when 3
        rand < 0.25
      when 4
        rand < 1/3
      else
        rand < .5

  criticalHitLevel: (battle, attacker, defender) =>
    stage = @chLevel
    stage += 1  if attacker.hasAbility('Super Luck')
    stage += 2  if attacker.name == "Farfetch'd" && attacker.hasItem('Stick')
    stage += 2  if attacker.name == "Chansey" && attacker.hasItem('Lucky Punch')
    stage += 1  if attacker.hasItem('Razor Claw')
    stage

  baseDamage: (battle, attacker, defender) =>
    floor = Math.floor
    baseDamage = floor((2 * attacker.level) / 5 + 2)
    # TODO: Apply variable base power
    baseDamage *= @basePower()
    baseDamage *= attacker.stat(whichAttackStat(@spectra))
    # TODO: Some moves act against the defense stat even if they're special.
    baseDamage = floor(baseDamage / defender.stat(whichDefenseStat(@spectra)))
    baseDamage += 2

  damage: (attacker, defender, amount) =>
    defender.currentHP -= amount
    amount

whichAttackStat = (spectra) ->
  spectra == (if 'physical' then 'attack' else 'special attack')

whichDefenseStat = (spectra) ->
  spectra == (if 'physical' then 'defense' else 'special defense')

Type =
  NORMAL   : 0
  FIRE     : 1
  WATER    : 2
  ELECTRIC : 3
  GRASS    : 4
  ICE      : 5
  FIGHTING : 6
  POISON   : 7
  GROUND   : 8
  FLYING   : 9
  PSYCHIC  : 10
  BUG      : 11
  ROCK     : 12
  GHOST    : 13
  DRAGON   : 14
  DARK     : 15
  STEEL    : 16

typeChart = [
  # Nor Fir Wat Ele Gra Ice Fig Poi Gro Fly Psy Bug Roc Gho Dra Dar Ste
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, .5,  0,  1,  1, .5 ], # Nor
  [  1, .5, .5,  1,  2,  2,  1,  1,  1,  1,  1,  2, .5,  1, .5,  1,  2 ], # Fir
  [  1,  2, .5,  1, .5,  1,  1,  1,  2,  1,  1,  1,  2,  1, .5,  1,  1 ], # Wat
  [  1,  1,  2, .5, .5,  1,  1,  1,  0,  2,  1,  1,  1,  1, .5,  1,  1 ], # Ele
  [  1, .5,  2,  1, .5,  1,  1, .5,  2, .5,  1, .5,  2,  1, .5,  1, .5 ], # Gra
  [  1, .5, .5,  1,  2, .5,  1,  1,  2,  2,  1,  1,  1,  1,  2,  1, .5 ], # Ice
  [  2,  1,  1,  1,  1,  2,  1, .5,  1, .5, .5, .5,  2,  0,  1,  2,  2 ], # Fig
  [  1,  1,  1,  1,  2,  1,  1, .5, .5,  1,  1,  1, .5, .5,  1,  1,  0 ], # Poi
  [  1,  2,  1,  2, .5,  1,  1,  2,  1,  0,  1, .5,  2,  1,  1,  1,  2 ], # Gro
  [  1,  1,  1, .5,  2,  1,  2,  1,  1,  1,  1,  2, .5,  1,  1,  1, .5 ], # Fly
  [  1,  1,  1,  1,  1,  1,  2,  2,  1,  1, .5,  1,  1,  1,  1,  0, .5 ], # Psy
  [  1, .5,  1,  1,  2,  1, .5, .5,  1, .5,  2,  1,  1, .5,  1,  2, .5 ], # Bug
  [  1,  2,  1,  1,  1,  2, .5,  1, .5,  2,  1,  2,  1,  1,  1,  1, .5 ], # Roc
  [  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1,  1,  2,  1, .5, .5 ], # Gho
  [  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  2,  1, .5 ], # Dra
  [  1,  1,  1,  1,  1,  1, .5,  1,  1,  1,  2,  1,  1,  2,  1,  1, .5 ], # Dar
  [  1, .5, .5, .5,  1,  2,  1,  1,  1,  1,  1,  1,  2,  1,  1,  1, .5 ], # Ste
]
