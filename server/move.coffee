{finalModifier, basePowerModifier, attackStatModifier} = require './modifiers'
{Status} = require './status'
{Attachment} = require './attachment'
util = require './util'

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
    @target = attributes.target
    @type = attributes.type || '???'
    @spectra = attributes.damage || '???'
    @chLevel = attributes.criticalHitLevel || 1
    @flags = attributes.flags
    @flinchChance = (attributes.flinchChance || 0) / 100
    @pp = attributes.pp

  isPhysical: ->
    @spectra == 'physical'

  isSpecial: ->
    @spectra == 'special'

  isNonDamaging: ->
    @spectra == 'non-damaging'

  hasFlag: (flagName) ->
    flagName in @flags

  # Executes this move on several targets.
  # Only override this method if the move does not need to be
  # recorded on the enemy pokemon.
  execute: (battle, user, targets) ->
    # TODO: Test the below 3 lines.
    if targets.length == 0
      battle.message "But there was no target..."
      return

    for target in targets
      numHits = @calculateNumberOfHits(battle, user, target)
      for i in [1..numHits]
        continue  if target.shouldBlockExecution(battle, this, user)
        if @use(battle, user, target) != false
          @hit(battle, user, target)

  # A hook with a default implementation of returning false on a type immunity.
  # If `use` returns false, the `afterSuccessfulHit` hook is never called.
  use: (battle, user, target) ->
    if @willMiss(battle, user, target)
      damage = @calculateDamage(battle, user, target)
      @afterMiss(battle, user, target, damage)
      return false

    type = @getType(battle, user, target)
    if target.isImmune(battle, type)
      battle.message "But it doesn't affect #{target.name}..."
      return false

  # Actually deals damage and runs hooks after hit.
  hit: (battle, user, target) ->
    damage = @calculateDamage(battle, user, target)
    if damage > 0
      # TODO: Print out opponent's name alongside the pokemon.
      battle.message "#{target.name} took #{damage} damage!"
      realDamage = target.transformHealthChange(damage)
      target.damage(realDamage)
    target.afterBeingHit(battle, this, user, target, damage)
    user.afterSuccessfulHit(battle, this, user, target, damage)
    @afterSuccessfulHit(battle, user, target, damage)
    target.recordHit(user, damage, this, battle.turn)

  # A hook that executes after a pokemon has been successfully damaged by
  # a standard move. If execute is overriden, this will not execute.
  afterSuccessfulHit: (battle, user, target, damage) ->

  # A hook that executes after a pokemon misses an attack. If execute is
  # overriden, this will not execute.
  afterMiss: (battle, user, target, damage) ->
    battle.message "#{target.name} avoided the attack!"

  # A hook that executes once a move fails.
  fail: (battle) ->
    battle.message "But it failed!"

  # A hook that is only used by special "specific-move" targets.
  getTargets: (battle, user) ->
    throw new Error("Move #{@name} has not implemented getTargets.")

  calculateDamage: (battle, user, target) ->
    return 0  if @power == 0

    willCritical = @isCriticalHit(battle, user, target)
    damage = @baseDamage(battle, user, target)
    # TODO: Multi-target modifier.
    damage = @modify(damage, @weatherModifier(battle, user, target))
    damage = damage * 2  if willCritical
    damage = Math.floor(((100 - battle.rng.randInt(0, 15, "damage roll")) * damage) / 100)
    damage = @modify(damage, @stabModifier(battle, user, target))
    damage = Math.floor(@typeEffectiveness(battle, user, target) * damage)
    damage = Math.floor(@burnCalculation(user) * damage)
    damage = Math.max(damage, 1)
    damage = @modify(damage, @modifyDamage(battle, user, target))
    damage = target.editDamage(battle, this, damage)
    damage = Math.min(target.currentHP, damage)

    if willCritical
      battle.message "A critical hit!"
      target.informCriticalHit(battle)
    damage

  willMiss: (battle, user, target) ->
    accuracy = @chanceToHit(battle, user, target)
    return false  if accuracy == 0
    battle.rng.randInt(1, 100, "miss") > accuracy

  chanceToHit: (battle, user, target) ->
    accuracy = @accuracy
    accuracy = Math.floor(accuracy * (3 + user.editBoosts().accuracy) / 3)
    accuracy = Math.floor(accuracy * 3 / (3 + target.editBoosts().evasion))
    accuracy = user.editAccuracy(accuracy)
    accuracy = target.editEvasion(accuracy)
    if user.hasItem("Zoom Lens") && battle.willMove(target)
      accuracy = Math.floor(accuracy * 1.2)
    # TODO: Accuracy/evasion ability modifiers
    accuracy

  weatherModifier: (battle, user, target) ->
    type = @getType(battle, user, target).toUpperCase()
    if type == 'Fire' and battle.hasWeather('Sunny')
      0x1800
    else if type == 'Fire' and battle.hasWeather('Rainy')
      0x0800
    else if type == 'Water' and battle.hasWeather('Rainy')
      0x1800
    else if type == 'Water' and battle.hasWeather('Sunny')
      0x0800
    else
      0x1000

  stabModifier: (battle, user, target) ->
    type = @getType(battle, user, target)
    if user.hasType(type)
      return 0x2000  if user.hasAbility("Adaptability")
      return 0x1800
    return 0x1000

  typeEffectiveness: (battle, user, target) ->
    type = @getType(battle, user, target)
    util.typeEffectiveness(type, target.types)

  burnCalculation: (user) ->
    if @isPhysical() && !user.hasAbility("Guts") && user.hasStatus(Status.BURN)
      .5
    else
      1

  basePower: (battle, user, target) ->
    @power

  isCriticalHit: (battle, attacker, defender) ->
    owner = battle.getOwner(defender)
    return false  if owner?.team.hasAttachment(Attachment.LuckyChant)
    return false  if defender.ability?.preventsCriticalHits

    rand = battle.rng.next("ch")
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

  criticalHitLevel: (battle, attacker, defender) ->
    # -1 means always crits
    return @chLevel  if @chLevel == -1

    stage = @chLevel
    stage += 1  if attacker.hasAbility('Super Luck')
    stage += 2  if attacker.hasAttachment(Attachment.FocusEnergy)
    stage += attacker.item?.criticalModifier(battle, attacker) || 0
    stage

  modify: (number, modifier) ->
    Math.ceil((number * modifier) / 0x1000 - 0.5)

  baseDamage: (battle, user, target) ->
    floor = Math.floor
    uStat = @pickAttackStat(user, target)
    tStat = @pickDefenseStat(user, target)
    damage = floor((2 * user.level) / 5 + 2)
    damage *= @basePower(battle, user, target)
    damage = @modify(damage, @modifyBasePower(battle, user, target))
    damage *= @modify(uStat, attackStatModifier.run(this, battle, user, target))
    damage = floor(damage / tStat)
    damage = floor(damage / 50)
    damage += 2
    damage

  calculateNumberOfHits: (battle, user, target) ->
    if @attributes.minHits == @attributes.maxHits
      @attributes.maxHits
    else if user.hasAbility("Skill Link")
      @attributes.maxHits
    else if @attributes.minHits == 2 && @attributes.maxHits == 5
      # hard coding moves like fury swipes to have 2-3 hits have a 1/3 chance, and 4-5 have 1/6th
      battle.rng.choice([2, 2, 3, 3, 4, 5], "num hits")
    else
      battle.rng.randInt(@attributes.minHits, @attributes.maxHits, "num hits")

  modifyBasePower: (battle, user, target) ->
    modify = user.attachments.queryModifiers('modifyBasePower', battle, this, user, target)
    modify = @modify(modify, target.attachments.queryModifiers('modifyBasePowerTarget', battle, this, user, target))
    # TODO: Deprecate
    modify = @modify(modify, basePowerModifier.run(this, battle, user, target))

  modifyDamage: (battle, user, target) ->
    modify = target.attachments.queryModifiers('modifyDamageTarget', battle, this, user)
    # TODO: Deprecate
    modify = @modify(modify, finalModifier.run(this, battle, user, target))

  getType: (battle, user, target) ->
    @type

  pickAttackStat: (user, target) ->
    stat = (if @isPhysical() then 'attack' else 'specialAttack')
    user.stat(stat)

  pickDefenseStat: (user, target) ->
    stat = (if @isPhysical() then 'defense' else 'specialDefense')
    target.stat(stat)

  toString: ->
    "[Move name:#{@name}]"
