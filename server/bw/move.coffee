{Attachment, Status} = require './attachment'
{Weather} = require '../../shared/weather'
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
    @primaryBoostStats = attributes.primaryBoostStats
    @primaryBoostTarget = attributes.primaryBoostTarget
    @secondaryBoostChance = attributes.secondaryBoostChance || 0
    @secondaryBoostStats = attributes.secondaryBoostStats
    @secondaryBoostTarget = attributes.secondaryBoostTarget
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

  hasPrimaryEffect: ->
    @primaryBoostStats? || (@ailmentId != "none" && @ailmentChance == 0)

  # A secondary effect also includes flinching.
  hasSecondaryEffect: ->
    (@ailmentChance > 0 && @ailmentId != "none") ||
      @flinchChance > 0 || @secondaryBoostChance > 0

  # Executes this move on several targets.
  # Only override this method if the move does not need to be
  # recorded on the enemy pokemon.
  execute: (battle, user, targets) ->
    # If there are no targets, then the move should automatically fail.
    # For example, Helping Hand may not have a target.
    return @fail(battle)  if targets.length == 0
    # If there were targets, but they are all no longer alive, then the engine
    # outputs a stock message and quits move execution.
    targets = targets.filter((p) -> p.isAlive())
    if targets.length == 0
      battle.cannedText('NO_TARGET')
      return

    # The move is executing. Run a hook.
    @executing(battle, user, targets)

    targetsHit = []
    totalDamage = 0
    for target in targets
      continue  if @use(battle, user, target, hitNumber) == false
      if target.shouldBlockExecution(this, user) == true
        @afterFail(battle, user, target)
        continue
      targetSlots = targets.map (target) ->
        return [ battle.playerIds.indexOf(target.playerId),
                 target.team.indexOf(target) ]
      user.tell(Protocol.MOVE_SUCCESS, targetSlots, @name)
      targetsHit.push(target)
      numHits = @calculateNumberOfHits(battle, user, targets)
      wasSlept = user.has(Status.Sleep)
      for hitNumber in [1..numHits]
        isDirect = @isDirectHit(battle, user, target)
        damage = @hit(battle, user, target, hitNumber, isDirect) || 0
        @afterHit(battle, user, target, damage, isDirect)
        totalDamage += damage
        break  if target.isFainted() || user.isFainted() ||
                  (!wasSlept && user.has(Status.Sleep))
      if numHits > 1
        battle.message @numHitsMessage Math.min(hitNumber, numHits)

    # Target faints if it has 0 HP.
    for target in targets when target.isFainted()
      target.faint()

    # Recoil moves
    if totalDamage > 0 && @recoil < 0 && !user.hasAbility("Rock Head")
      recoil = Math.round(totalDamage * -@recoil / 100)
      if user.damage(recoil)
        battle.cannedText('RECOIL', user)

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
    if target.isImmune(@getType(battle, user, target), user: user, move: this)
      battle.cannedText('IMMUNITY', target)
      @afterFail(battle, user, target)
      return false

    if @willMiss(battle, user, target)
      battle.cannedText('MOVE_MISS', target)
      @afterMiss(battle, user, target)
      return false

  # Actually deals damage and runs hooks after hit.
  hit: (battle, user, target, hitNumber, isDirect) ->
    damage = @calculateDamage(battle, user, target, hitNumber, isDirect)
    if damage > 0
      previousHP = target.get(Attachment.Substitute)?.hp ? target.currentHP
      damage = target.damage(damage, direct: isDirect, source: "move")
      if damage != 0
        # TODO: Print out opponent's name alongside the pokemon.
        percent = Math.floor(100 * damage / target.stat('hp'))
        battle.cannedText('GOT_HIT', target, percent)
      else
        currentHP = target.get(Attachment.Substitute)?.hp ? target.currentHP
        damage = previousHP - Math.max(0, currentHP)
    return damage

  # `hit` may be overridden, but we still want to run these callbacks.
  afterHit: (battle, user, target, damage, isDirect) ->
    # Drain moves
    if damage > 0 && @recoil > 0
      amount = Math.round(damage * @recoil / 100)
      user.drain(amount, target)
      battle.cannedText('DRAIN', target)
      battle.cannedText('ABSORB', user)

    if isDirect && @shouldTriggerSecondary(battle, user, target)
      @triggerSecondaryEffect(battle, user, target)
    user.afterSuccessfulHit(this, user, target, damage, isDirect)
    target.afterBeingHit(this, user, target, damage, isDirect)
    @afterSuccessfulHit(battle, user, target, damage, isDirect)

    # Miscellaneous
    target.recordHit(user, damage, this, battle.turn, isDirect)

  # A hook that runs when the move is finally executing.
  executing: (battle, user, targets) ->

  # A hook that executes after a pokemon has been successfully damaged by
  # a standard move. If execute is overriden, this will not execute.
  afterSuccessfulHit: (battle, user, target, damage) ->

  # A hook that executes after a pokemon misses an attack. If execute is
  # overriden, this will not execute.
  afterMiss: (battle, user, target) ->

  # A hook that executes after a pokemon fails while using a move (NOT a miss.)
  # Examples: Target is immune, target successfully uses Protect/Detect
  afterFail: (battle, user, target) ->

  # A hook that executes after all hits have completed.
  afterAllHits: (battle, user) ->

  # A hook that executes when asking if this move should do direct damage
  isDirectHit: (battle, user, target) ->
    return true   if @hasFlag('authentic')
    return !target.has(Attachment.Substitute)

  # A hook that executes once a move fails.
  fail: (battle) ->
    battle.cannedText('MOVE_FAIL')

  numHitsMessage: (hitNumber) ->
    return "Hit #{hitNumber} time(s)!"

  # A hook that is only used by special "specific-move" targets.
  getTargets: (battle, user) ->
    throw new Error("Move #{@name} has not implemented getTargets.")

  calculateDamage: (battle, user, target, hitNumber=1, isDirect) ->
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
      battle.cannedText('NOT_VERY_EFFECTIVE')
    else if effectiveness > 1
      battle.cannedText('SUPER_EFFECTIVE')

    if user.crit
      battle.cannedText('CRITICAL_HIT')
      target.informCriticalHit()
    damage

  willMiss: (battle, user, target) ->
    accuracy = @chanceToHit(battle, user, target)
    return false  if accuracy == 0
    battle.rng.randInt(1, 100, "miss") > accuracy

  chanceToHit: (battle, user, target) ->
    return 0  if user == target
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

  shouldTriggerSecondary: (battle, user, target) ->
    return false  if !@hasSecondaryEffect()
    return false  if user.hasAbility("Sheer Force")
    return false  if target.hasAbility("Shield Dust") && @secondaryBoostTarget != 'self'
    return true

  triggerSecondaryEffect: (battle, user, target) ->
    # Multiply chances by 2 if the user has Serene Grace.
    chanceMultiplier = (if user.hasAbility("Serene Grace") then 2 else 1)

    # Secondary effects
    if @ailmentChance > 0 && battle.rng.randInt(0, 99, "secondary effect") < @ailmentChance * chanceMultiplier
      target.attach(battle.getAilmentEffect(this), source: user)

    # Secondary boosts
    if @secondaryBoostChance > 0 && battle.rng.randInt(0, 99, "secondary boost") < @secondaryBoostChance * chanceMultiplier
      pokemon = (if @secondaryBoostTarget == 'self' then user else target)
      pokemon.boost(@secondaryBoostStats, user)

    # Flinching. In the game, flinching is treated subtly different than
    # secondary effects. One result is that the Fang moves can both inflict
    # a secondary effect as well as flinch.
    if @flinchChance > 0 && battle.rng.randInt(0, 99, "flinch") < @flinchChance * chanceMultiplier
      target.attach(Attachment.Flinch)

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
