{Attachment, Status} = require './attachment'
{Weather} = require './weather'
{Protocol} = require '../../shared/protocol'
Query = require('./queries')
util = require './util'

# A single Move in the Pokemon engine. Move objects are constructed in
# data/VERSION/moves.coffee, with only one instance per move (for example,
# there is only one Flamethrower). These instances are retrieved by the battle
# engine.
class @Move
  criticalMultiplier: 2

  constructor: (@name, attributes = {}) ->
    @accuracy = attributes.accuracy || 0
    @priority = attributes.priority || 0
    @power = attributes.power
    @target = attributes.target
    @type = attributes.type || '???'
    @spectra = attributes.damage || '???'
    @chLevel = attributes.criticalHitLevel || 1
    @flags = attributes.flags || []
    @flinchChance = (attributes.flinchChance || 0)
    @ailmentChance = (attributes.ailmentChance || 0)
    @ailmentId = attributes.ailmentId
    @boostChance = attributes.boostChance || 0
    @boostStats = attributes.boostStats
    @boostTarget = attributes.boostTarget
    @pp = attributes.pp
    @recoil = attributes.recoil
    {@minHits, @maxHits} = attributes

  isPhysical: ->
    @spectra == 'physical'

  isSpecial: ->
    @spectra == 'special'

  isNonDamaging: ->
    @spectra == 'non-damaging'

  hasFlag: (flagName) ->
    flagName in @flags

  # A secondary effect also includes flinching.
  hasSecondaryEffect: ->
    (@ailmentChance > 0 && @ailmentId != "none") ||
      @flinchChance > 0 || @boostChance > 0

  # Executes this move on several targets.
  # Only override this method if the move does not need to be
  # recorded on the enemy pokemon.
  execute: (battle, user, targets) ->
    # TODO: Test the below 3 lines.
    if targets.length == 0
      battle.message "But there was no target..."
      return

    targetsHit = []
    for target in targets
      continue  if @use(battle, user, target, hitNumber) == false
      continue  if target.shouldBlockExecution(this, user) == true
      targetsHit.push(target)
      numHits = @calculateNumberOfHits(battle, user, targets)
      for hitNumber in [1..numHits]
        @hit(battle, user, target, hitNumber)
        break  if target.isFainted()
      if numHits > 1
        battle.message @numHitsMessage Math.min(hitNumber, numHits)

    # If the move hit 1+ times, query the user's afterAllHits event.
    # If the user is affected by Sheer Force, these are all ignored.
    if targetsHit.length > 0 &&
        (!user.hasAbility("Sheer Force") || !@hasSecondaryEffect())
      user.afterAllHits(this)
      @afterAllHits(battle, user)
      for target in targetsHit
        target.afterAllHitsTarget(this, user)

  # A hook with a default implementation of returning false on a type immunity.
  # If `use` returns false, the `hit` hook is never called.
  use: (battle, user, target, hitNumber) ->
    if @willMiss(battle, user, target)
      @afterMiss(battle, user, target)
      return false

    if target.isImmune(@getType(battle, user, target), move: this)
      @afterImmune(battle, user, target)
      return false

  # Actually deals damage and runs hooks after hit.
  hit: (battle, user, target, hitNumber) ->
    damage = @calculateDamage(battle, user, target, hitNumber)
    if damage > 0
      previousHP = target.get(Attachment.Substitute)?.hp ? target.currentHP
      damage = target.damage(damage, direct: false, source: "move")
      if damage != 0
        # TODO: Print out opponent's name alongside the pokemon.
        percent = Math.floor(100 * damage / target.stat('hp'))
        battle.message "#{target.name} took #{percent}% damage!"
      else
        currentHP = target.get(Attachment.Substitute)?.hp ? target.currentHP
        damage = previousHP - Math.max(0, currentHP)
    user.afterSuccessfulHit(this, user, target, damage)
    @afterSuccessfulHit(battle, user, target, damage)
    target.afterBeingHit(this, user, target, damage)

    # Recoil
    if @recoil < 0 && !user.hasAbility("Rock Head")
      recoil = Math.round(-damage * @recoil / 100)
      recoil = Math.max(1, recoil)
      if user.damage(recoil)
        battle.message("#{user.name} was hit by recoil!")

    # Miscellaneous
    target.recordHit(user, damage, this, battle.turn)

  # A hook that executes after a pokemon has been successfully damaged by
  # a standard move. If execute is overriden, this will not execute.
  afterSuccessfulHit: (battle, user, target, damage) ->

  # A hook that executes after a pokemon misses an attack. If execute is
  # overriden, this will not execute.
  afterMiss: (battle, user, target) ->
    battle.message "#{target.name} avoided the attack!"

  # A hook that executes after a pokemon uses a move which the target is immune to.
  afterImmune: (battle, user, target) ->
    battle.message "But it doesn't affect #{target.name}..."

  # A hook that executes after all hits have completed.
  afterAllHits: (battle, user) ->

  # A hook that executes once a move fails.
  fail: (battle) ->
    battle.message "But it failed!"

  numHitsMessage: (hitNumber) ->
    return "Hit #{hitNumber} time(s)!"

  # A hook that is only used by special "specific-move" targets.
  getTargets: (battle, user) ->
    throw new Error("Move #{@name} has not implemented getTargets.")

  calculateDamage: (battle, user, target, hitNumber=1) ->
    return 0  if @basePower(battle, user, target, hitNumber) == 0

    user.crit = @isCriticalHit(battle, user, target)
    damage = @baseDamage(battle, user, target, hitNumber)
    # TODO: Multi-target modifier.
    damage = @modify(damage, @weatherModifier(battle, user, target))
    damage = damage * @criticalMultiplier  if user.crit
    damage = Math.floor(((100 - battle.rng.randInt(0, 15, "damage roll")) * damage) / 100)
    damage = @modify(damage, @stabModifier(battle, user, target))
    effectiveness = @typeEffectiveness(battle, user, target)
    damage = Math.floor(effectiveness * damage)
    damage = Math.floor(@burnCalculation(user) * damage)
    damage = Math.max(damage, 1)
    damage = @modify(damage, @modifyDamage(battle, user, target, hitNumber))
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
    userBoosts = user.editBoosts(ignoreAccuracy: target.hasAbility("Unaware"))
    targetBoosts = target.editBoosts(ignoreEvasion: user.hasAbility("Unaware"))
    accuracy = @getAccuracy(battle, user, target)
    if userBoosts.accuracy > 0
      accuracy = Math.floor(accuracy * (3 + userBoosts.accuracy) / 3)
    else if userBoosts.accuracy < 0
      accuracy = Math.floor(accuracy / (3 - userBoosts.accuracy) * 3)
    if targetBoosts.evasion > 0
      accuracy = Math.floor(accuracy / (3 + targetBoosts.evasion) * 3)
    else if targetBoosts.evasion < 0
      accuracy = Math.floor(accuracy * (3 - targetBoosts.evasion) / 3)
    accuracy = user.editAccuracy(accuracy, this, target)
    accuracy = target.editEvasion(accuracy, this, user)
    accuracy

  getAccuracy: (battle, user, target) ->
    @accuracy

  weatherModifier: (battle, user, target) ->
    # TODO: This is wrong.
    type = @getType(battle, user, target)
    if type == 'Fire' && battle.hasWeather(Weather.SUN)
      0x1800
    else if type == 'Fire' && battle.hasWeather(Weather.RAIN)
      0x800
    else if type == 'Water' && battle.hasWeather(Weather.RAIN)
      0x1800
    else if type == 'Water' && battle.hasWeather(Weather.SUN)
      0x800
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
    target.effectivenessOf(type, user: user, move: this)

  burnCalculation: (user) ->
    if @isPhysical() && !user.hasAbility("Guts") && user.has(Status.Burn)
      .5
    else
      1

  basePower: (battle, user, target, hitNumber) ->
    @power

  isCriticalHit: (battle, attacker, defender) ->
    return false  if defender.team?.has(Attachment.LuckyChant)
    return false  if defender.ability?.preventsCriticalHits

    chLevel = @criticalHitLevel(battle, attacker, defender)
    rand = battle.rng.next("ch")
    @determineCriticalHitFromLevel(chLevel, rand)

  determineCriticalHitFromLevel: (level, rand) ->
    switch level
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

  baseDamage: (battle, user, target, hitNumber=1) ->
    floor = Math.floor
    uStat = @pickAttackStat(user, target)
    tStat = @pickDefenseStat(user, target)
    if battle.hasWeather(Weather.SAND) && target.hasType("Rock") && @isSpecial()
      tStat = @modify(tStat, 0x1800)
    damage = floor((2 * user.level) / 5 + 2)
    damage *= @basePower(battle, user, target, hitNumber)
    damage = @modify(damage, @modifyBasePower(battle, user, target))
    damage *= @modify(uStat, @modifyAttack(battle, user, target))
    damage = floor(damage / tStat)
    damage = floor(damage / 50)
    damage += 2
    damage

  calculateNumberOfHits: (battle, user, targets) ->
    numHits = user.calculateNumberOfHits(this, targets)
    if numHits
      numHits
    else if @minHits == @maxHits
      @maxHits
    else if @minHits == 2 && @maxHits == 5
      # hard coding moves like fury swipes to have 2-3 hits have a 1/3 chance, and 4-5 have 1/6th
      battle.rng.choice([2, 2, 3, 3, 4, 5], "num hits")
    else
      battle.rng.randInt(@minHits, @maxHits, "num hits")

  modifyBasePower: (battle, user, target) ->
    modify = Query.modifiers("modifyBasePower", user.attachments.all(), this, target)
    modify = @modify(modify, Query.modifiers("modifyBasePowerTarget", target.attachments.all(), this, user))

  modifyDamage: (battle, user, target, hitNumber) ->
    modify = Query.modifiers('modifyDamageTarget', target.team.attachments.all(), this, user, hitNumber)
    modify = @modify(modify, Query.modifiers('modifyDamage', user.attachments.all(), this, target, hitNumber))
    modify = @modify(modify, Query.modifiers('modifyDamageTarget', target.attachments.all(), this, user, hitNumber))

  modifyAttack: (battle, user, target) ->
    modify = Query.modifiers('modifyAttack', user.attachments.all(), this, target)
    modify = @modify(modify, Query.modifiers('modifyAttackTarget', target.attachments.all(), this, user))

  getType: (battle, user, target) ->
    type = user.editMoveType(@type, target)
    type

  pickAttackStat: (user, target) ->
    stat = (if @isPhysical() then 'attack' else 'specialAttack')
    user.stat(stat, ignoreNegativeBoosts: user.crit, ignoreOffense: target.hasAbility("Unaware"))

  pickDefenseStat: (user, target) ->
    stat = (if @isPhysical() then 'defense' else 'specialDefense')
    target.stat(stat, ignorePositiveBoosts: user.crit, ignoreDefense: user.hasAbility("Unaware"))

  toString: ->
    "[Move name:#{@name}]"
