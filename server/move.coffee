{Status} = require './status'
{Attachment} = require './attachment'
{Protocol} = require '../shared/protocol'
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
    @recoil = attributes.recoil

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
      continue  if target.shouldBlockExecution(this, user)
      numHits = @calculateNumberOfHits(battle, user, target)
      for i in [1..numHits]
        if @use(battle, user, target) != false
          @hit(battle, user, target)

  # A hook with a default implementation of returning false on a type immunity.
  # If `use` returns false, the `afterSuccessfulHit` hook is never called.
  use: (battle, user, target) ->
    if @willMiss(battle, user, target)
      damage = @calculateDamage(battle, user, target)
      @afterMiss(battle, user, target, damage)
      return false

    if target.isImmune(@getType(battle, user, target), this)
      battle.message "But it doesn't affect #{target.name}..."
      return false

  # Actually deals damage and runs hooks after hit.
  hit: (battle, user, target) ->
    user.tell(Protocol.MOVE_SUCCESS, target.team.indexOf(target))
    damage = @calculateDamage(battle, user, target)
    if damage > 0
      # TODO: Print out opponent's name alongside the pokemon.
      battle.message "#{target.name} took #{damage} damage!"
      realDamage = target.transformHealthChange(damage)
      target.damage(realDamage)
    target.afterBeingHit(this, user, target, damage)
    user.afterSuccessfulHit(this, user, target, damage)
    @afterSuccessfulHit(battle, user, target, damage)
    if @recoil < 0 && !user.hasAbility("Rock Head")
      recoil = Math.round(-damage * @recoil / 100)
      recoil = Math.max(1, recoil)
      user.damage(recoil)
      battle.message("#{user.name} was hit by recoil!")
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
    return 0  if @basePower(battle, user, target) == 0

    user.crit = @isCriticalHit(battle, user, target)
    damage = @baseDamage(battle, user, target)
    # TODO: Multi-target modifier.
    damage = @modify(damage, @weatherModifier(battle, user, target))
    damage = damage * 2  if user.crit
    damage = Math.floor(((100 - battle.rng.randInt(0, 15, "damage roll")) * damage) / 100)
    damage = @modify(damage, @stabModifier(battle, user, target))
    effectiveness = @typeEffectiveness(battle, user, target)
    damage = Math.floor(effectiveness * damage)
    damage = Math.floor(@burnCalculation(user) * damage)
    damage = Math.max(damage, 1)
    damage = @modify(damage, @modifyDamage(battle, user, target))
    damage = target.editDamage(this, damage)

    if effectiveness < 1
      battle.message "It's not very effective..."
    else if effectiveness > 1
      battle.message "It's super effective!"

    if user.crit
      battle.message "A critical hit!"
      target.informCriticalHit()
    damage

  willMiss: (battle, user, target) ->
    accuracy = @chanceToHit(battle, user, target)
    return false  if accuracy == 0
    battle.rng.randInt(1, 100, "miss") > accuracy

  chanceToHit: (battle, user, target) ->
    accuracy = @accuracy
    accuracy = Math.floor(accuracy * (3 + user.editBoosts().accuracy) / 3)
    accuracy = Math.floor(accuracy * 3 / (3 + target.editBoosts().evasion))
    accuracy = user.editAccuracy(accuracy, this, target)
    accuracy = target.editEvasion(accuracy, this, user)
    accuracy

  weatherModifier: (battle, user, target) ->
    # TODO: This is wrong.
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

  ignoresImmunities: ->
    @isNonDamaging()

  typeEffectiveness: (battle, user, target) ->
    type = @getType(battle, user, target)
    options = {ignoreImmunities: user.hasAbility("Scrappy")}
    type = "Normal"  if user.hasAbility("Normalize") && user != target
    util.typeEffectiveness(type, target.types, options)

  burnCalculation: (user) ->
    if @isPhysical() && !user.hasAbility("Guts") && user.has(Status.Burn)
      .5
    else
      1

  basePower: (battle, user, target) ->
    @power

  isCriticalHit: (battle, attacker, defender) ->
    owner = battle.getOwner(defender)
    return false  if owner?.team.has(Attachment.LuckyChant)
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
    stage += 2  if attacker.has(Attachment.FocusEnergy)
    stage += attacker.criticalModifier()
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
    damage *= @modify(uStat, @modifyAttack(battle, user, target))
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
    modify = user.attachments.queryModifiers('modifyBasePower', this, user, target)
    modify = @modify(modify, target.attachments.queryModifiers('modifyBasePowerTarget', this, user))

  modifyDamage: (battle, user, target) ->
    {team} = battle.getOwner(target)
    modify = team.attachments.queryModifiers('modifyDamageTarget', this, user)
    modify = @modify(modify, user.attachments.queryModifiers('modifyDamage', this, target))
    modify = @modify(modify, target.attachments.queryModifiers('modifyDamageTarget', this, user))

  modifyAttack: (battle, user, target) ->
    modify = user.attachments.queryModifiers('modifyAttack', this, target)
    modify = @modify(modify, target.attachments.queryModifiers('modifyAttackTarget', this, user))

  getType: (battle, user, target) ->
    @type

  pickAttackStat: (user, target) ->
    stat = (if @isPhysical() then 'attack' else 'specialAttack')
    user.stat(stat, ignoreNegativeBoosts: user.crit)

  pickDefenseStat: (user, target) ->
    stat = (if @isPhysical() then 'defense' else 'specialDefense')
    target.stat(stat, ignorePositiveBoosts: user.crit)

  toString: ->
    "[Move name:#{@name}]"
