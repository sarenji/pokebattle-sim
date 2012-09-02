{finalModifier, basePowerModifier, stabModifier} = require './modifiers'
{Status} = require './status'

# A single Move in the Pokemon engine. Move objects are constructed in
# data/VERSION/moves.coffee, with only one instance per move (for example,
# there is only one Flamethrower). These instances are retrieved by the battle
# engine.
class @Move
  constructor: (@name, attributes = {}) ->
    @attributes = attributes
    @accuracy = attributes.accuracy || 0
    @priority = attributes.priority || 0
    @power = attributes.power
    @type = attributes.type || '???'
    @spectra = attributes.damage || '???'
    @chLevel = attributes.criticalHitLevel || 1

  # Executes this move on several targets.
  execute: (battle, user, targets) =>
    # TODO: Test the below 3 lines.
    if targets.length == 0
      battle.message "But there was no target..."
      return

    for target in targets
      damage = @calculateDamage(battle, user, target)
      if @willMiss(battle, user, target)
        @afterMiss(battle, user, target, damage)
        continue

      if damage > 0
        # TODO: Print out opponent's name alongside the pokemon.
        battle.message "#{target.name} took #{damage} damage!"
        target.damage(damage)

      @afterSuccessfulHit(battle, user, target, damage)

  # A hook that executes after a pokemon has been successfully damaged by
  # a standard move. If execute is overriden, this will not execute.
  afterSuccessfulHit: (battle, user, target, damage) =>

  # A hook that executes after a pokemon misses an attack. If execute is
  # overriden, this will not execute.
  afterMiss: (battle, user, target, damage) =>
    battle.message "#{target.name} avoided the attack!"

  calculateDamage: (battle, user, target) =>
    return 0  if @power == 0
    damage = @baseDamage(battle, user, target)
    # TODO: Multi-target modifier.
    damage = @modify(damage, @weatherModifier(battle))
    damage = damage * 2  if @isCriticalHit(battle, user, target)
    damage = Math.floor(((100 - battle.rng.randInt(0, 15)) * damage) / 100)
    damage = @modify(damage, stabModifier.run(this, battle, user, target))
    damage = Math.floor(@typeEffectiveness(target) * damage)
    damage = Math.floor(@burnCalculation(user) * damage)
    damage = Math.max(damage, 1)
    damage = @modify(damage, finalModifier.run(this, battle, user, target))
    damage

  willMiss: (battle, user, target) =>
    battle.rng.randInt(1, 100) > @chanceToHit(battle, user, target)

  chanceToHit: (battle, user, target) =>
    return 100  if @accuracy == 0
    accuracy = @accuracy
    accuracy = Math.floor(accuracy * (3 + user.stages.accuracy) / 3)
    accuracy = Math.floor(accuracy * 3 / (3 + target.stages.evasion))
    # TODO: Accuracy/evasion item modifiers
    # TODO: Accuracy/evasion ability modifiers
    # TODO: Gravity modifier
    accuracy

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

  typeEffectiveness: (target) =>
    effectiveness = 1
    userType = Type[@type.toUpperCase()]
    for subtype in target.types
      targetType = Type[subtype.toUpperCase()]
      effectiveness *= typeChart[userType][targetType]
    effectiveness

  burnCalculation: (user) =>
    if @spectra == "physical" && !user.hasAbility("Guts")\
                              &&  user.hasStatus(Status.BURN)
      .5
    else
      1

  basePower: (battle, user, target) =>
    @power

  isCriticalHit: (battle, attacker, defender) =>
    # TODO: Implement Lucky Chant.
    # TODO: Implement moves that always critical hit.
    if defender.hasAbility('Battle Armor') || defender.hasAbility('Shell Armor')
      return false

    rand = battle.rng.next()
    switch @criticalHitLevel(battle, attacker, defender)
      when -1
        true
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
    # -1 means always crits
    return @chLevel  if @chLevel == -1

    stage = @chLevel
    stage += 1  if attacker.hasAbility('Super Luck')
    stage += 2  if attacker.name == "Farfetch'd" && attacker.hasItem('Stick')
    stage += 2  if attacker.name == "Chansey" && attacker.hasItem('Lucky Punch')
    stage += 1  if attacker.hasItem('Razor Claw')
    stage

  modify: (number, modifier) =>
    Math.ceil((number * modifier) / 0x1000 - 0.5)

  baseDamage: (battle, user, target) =>
    floor = Math.floor
    damage = floor((2 * user.level) / 5 + 2)
    # TODO: Apply variable base power
    damage *= @basePower(battle, user, target)
    damage = @modify(damage, basePowerModifier.run(this, battle, user, target))
    damage *= user.stat(whichAttackStat(@spectra))
    # TODO: Some moves act against the defense stat even if they're special.
    damage = floor(damage / target.stat(whichDefenseStat(@spectra)))
    damage = floor(damage / 50)
    damage += 2
    damage

whichAttackStat = (spectra) ->
  (if spectra == 'physical' then 'attack' else 'specialAttack')

whichDefenseStat = (spectra) ->
  (if spectra == 'physical' then 'defense' else 'specialDefense')

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
