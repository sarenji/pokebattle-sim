@MoveData = require('./data_moves.json')
{Weather} = require('../../../shared/weather')
{Move} = require('../move')
{Attachment, Status} = require('../attachment')
{Ability} = require ('./abilities')
{Protocol} = require('../../../shared/protocol')
{_} = require 'underscore'
util = require '../util'
HiddenPower = require '../../../shared/hidden_power'

# Generate the initial versions of every single move.
# Many will be overwritten later.
@Moves = Moves = {}
@MoveList = MoveList = []
for name, attributes of @MoveData
  @Moves[name] = new Move(name, attributes)
  MoveList.push(@Moves[name])

# Extends a move in the move list using a callback.
#
# name -      The name of the move to extend.
# callback -  The function that will extend the move. 'this'
#             is the move object itself.
#
# Example:
#
#   extendMove 'Substitute', (attributes) ->
#     @initialize = -> # blah
#     @afterMove = -> # blah
#
extendMove = (name, callback) ->
  if name not of Moves
    throw new Error("Cannot extend Move '#{name}' because it does not exist.")

  move = Moves[name]
  callback.call(move, move.attributes)

# We add primary boost moves to the "hit" handler.
for move in MoveList
  if move.hasPrimaryEffect()
    extendMove move.name, ->
      @hit = (battle, user, target) ->
        if @primaryBoostStats?
          pokemon = (if @primaryBoostTarget == 'self' then user else target)
          pokemon.boost(@primaryBoostStats, user)
        if @ailmentId != 'none' && @ailmentChance == 0
          effect = battle.getAilmentEffect(this)
          if !target.attach(effect, source: user)
            @fail(battle)

makeJumpKick = (name, recoilPercent=.5) ->
  extendMove name, ->
    @afterMiss = @afterFail = (battle, user, target) ->
      maxHP = user.stat('hp')
      user.damage(Math.floor(maxHP / 2))
      battle.cannedText('JUMP_KICK_MISS', user)

makeWeightBased = (name) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      weight = target.calculateWeight()
      if weight <= 100       then 20
      else if weight <= 250  then 40
      else if weight <= 500  then 60
      else if weight <= 1000 then 80
      else if weight <= 2000 then 100
      else                        120

makeWeightRatioBased = (name) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      n = target.calculateWeight() / user.calculateWeight()
      if n < .2       then 120
      else if n < .25 then 100
      else if n < 1/3 then 80
      else if n < .5  then 60
      else                 40

makeLevelAsDamageMove = (name) ->
  extendMove name, ->
    @calculateDamage = (battle, user, target) ->
      user.level

makeReversalMove = (name) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      n = Math.floor(64 * user.currentHP / user.stat('hp'))
      if n <= 1       then 200
      else if n <= 5  then 150
      else if n <= 12 then 100
      else if n <= 21 then 80
      else if n <= 42 then 40
      else if n <= 64 then 20

makeEruptionMove = (name) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      power = Math.floor(150 * (user.currentHP / user.stat('hp')))
      Math.max(power, 1)

makeStatusCureAttackMove = (moveName, status) ->
  extendMove moveName, ->
    @basePower = (battle, user, target) ->
      if target.has(status) then 2 * @power else @power

    @afterSuccessfulHit = (battle, user, target) ->
      target.cureStatus(status)  unless user.isFainted()

makeOneHitKOMove = (name) ->
  extendMove name, ->
    @calculateDamage = (battle, user, target) ->
      # TODO: Or was this fixed?
      target.stat('hp')
    @afterSuccessfulHit = (battle, user, target, damage) ->
      # TODO: Is this message displayed even if the Pokemon survives?
      battle.message "It was a one-hit KO!"
    @chanceToHit = (battle, user, target) ->
      (user.level - target.level) + 30

makeRecoveryMove = (name) ->
  extendMove name, ->
    @use = (battle, user, target) ->
      hpStat = target.stat('hp')
      if target.currentHP == hpStat
        @fail(battle)
        return false
      amount = Math.round(hpStat / 2)
      percent = Math.floor(100 * amount / hpStat)
      battle.cannedText('RECOVER_HP', target, percent)
      target.heal(amount)

makeBasePowerBoostMove = (name, rawBasePower, maxBasePower, what) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      pokemon = {user, target}[what]
      # NOTE: the 20 is hardcoded; perhaps this will change later?
      power = rawBasePower + 20 * pokemon.positiveBoostCount()
      Math.min(power, maxBasePower)

makeWeatherRecoveryMove = (name) ->
  extendMove name, ->
    @use = (battle, user, target) ->
      hpStat = target.stat('hp')
      amount = if battle.hasWeather(Weather.NONE)
        util.roundHalfDown(hpStat / 2)
      else if battle.hasWeather(Weather.SUN)
        util.roundHalfDown(hpStat * 2 / 3)
      else
        util.roundHalfDown(hpStat / 4)
      percent = Math.floor(100 * amount / hpStat)
      battle.cannedText('RECOVER_HP', target, percent)
      target.heal(amount)

makeTrickMove = (name) ->
  extendMove name, ->
    @use = ->

    @afterSuccessfulHit = (battle, user, target) ->
      if (user.hasItem() && !user.hasTakeableItem()) ||
          (target.hasItem() && !target.canLoseItem()) ||
          (!target.hasItem() && !user.hasItem())
        @fail(battle)
        return false
      uItem = user.removeItem()
      tItem = target.removeItem()
      battle.cannedText('TRICK_START', user)
      if tItem
        battle.cannedText('TRICK_END', user, tItem)
        user.setItem(tItem)
      if uItem
        battle.cannedText('TRICK_END', target, uItem)
        target.setItem(uItem)

makeExplosionMove = (name) ->
  extendMove name, ->
    oldExecute = @execute
    @execute = (battle, user, targets) ->
      if !_.any(targets, (target) -> target.hasAbility('Damp'))
        user.faint()
        oldExecute.call(this, battle, user, targets)
      else
        @fail(battle)

    @fail = (battle) ->
      battle.message "#{user.name} cannot use #{@name}!"

makeProtectCounterMove = (name, callback) ->
  extendMove name, ->
    @execute = (battle, user, targets) ->
      # Protect fails if the user is the last to move.
      if !battle.hasActionsLeft()
        user.unattach(Attachment.ProtectCounter)
        @fail(battle)
        return

      # Calculate and roll chance of success
      attachment = user.attach(Attachment.ProtectCounter)
      attachment.turns = 2
      chance = attachment.successChance()
      if battle.rng.randInt(1, chance, "protect") > 1
        user.unattach(Attachment.ProtectCounter)
        @fail(battle)
        return

      # Success!
      callback.call(this, battle, user, targets)

makeOpponentFieldMove = (name, func) ->
  extendMove name, ->
    @execute = (battle, user, opponentIds) ->
      userId = battle.getOwner(user)
      for id in opponentIds
        team = battle.getTeam(id)
        continue  if team.shouldBlockFieldExecution(this, userId)
        func.call(this, battle, user, id)

makeProtectMove = (name) ->
  makeProtectCounterMove name, (battle, user, targets) ->
    user.attach(Attachment.Protect)

makeIdentifyMove = (name, types) ->
  extendMove name, ->
    @use = (battle, user, target) ->
      if target.attach(Attachment.Identify, {types})
        battle.message "#{target.name} was identified!"
      else
        @fail(battle)
        false

makePluckMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      item = target.getItem()
      if user.isAlive() && item?.type == 'berries'
        item.eat(battle, user)
        target.removeItem()

makeThiefMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      return  if user.hasItem() || !target.canLoseItem() || user.isFainted()
      battle.cannedText('THIEF_START', user, target, target.item)
      user.setItem(target.item)
      target.removeItem()

makeStatusCureMove = (name, message) ->
  extendMove name, ->
    @execute = (battle, user, targets) ->
      battle.message(message)
      for target in targets
        target.cureStatus(message: false)

makePickAttackMove = (name) ->
  extendMove name, ->
    @pickAttackStat = (user, target) ->
      target.stat('attack', ignoreNegativeBoosts: user.crit)

makePickDefenseMove = (name) ->
  extendMove name, ->
    @pickDefenseStat = (user, target) ->
      target.stat('defense', ignorePositiveBoosts: user.crit)

makeDelayedAttackMove = (name, message) ->
  extendMove name, ->
    @execute = (battle, user, targets) ->
      # These moves pick a single target.
      target = targets[0]
      if !target.team.attach(Attachment.DelayedAttack, user: user, move: this)
        @fail(battle)
        return
      battle.message message.replace("$1", user.name)

makeRandomSwitchMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage, isDirect) ->
      return  if !isDirect
      return  if target.isFainted() || user.isFainted()
      return  if target.shouldPhase(battle, user) == false
      {team}  = target
      benched = team.getAliveBenchedPokemon()
      return  if benched.length == 0
      pokemon = battle.rng.choice(benched)
      team.switch(target, team.indexOf(pokemon))

makeRampageMove = (moveName) ->
  extendMove moveName, ->
    @afterSuccessfulHit = (battle, user, target) ->
      user.attach(Attachment.Rampage, move: this)

makeRampageMove("Outrage")
makeRampageMove("Petal Dance")
makeRampageMove("Thrash")

# TODO: Does it fail if using twice, but on a different target?
# From PokemonLab:
# TODO: Major research is required here. Does Lock On make the next move to
#       target the subject hit; the next move to target the subject on the
#       next turn; all moves targeting the subject on the turn turn; or some
#       other possibility?
makeLockOnMove = (name) ->
  extendMove name, ->
    @use = (battle, user, target) ->
      if user.attach(Attachment.LockOn, {target})
        battle.message "#{user.name} locked onto #{target.name}."
      else
        @fail(battle)
        return false

makeStompMove = (name) ->
  extendMove name, ->
    @basePower = (battle, user, target) ->
      if target.has(Attachment.Minimize)
        2 * @power
      else
        @power

makeMeanLookMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      if target.attach(Attachment.MeanLook)
        battle.message "#{target.name} can no longer escape!"
      else
        @fail(battle)
        return false

makeChargeMove = (name, args...) ->
  condition = args.pop()  if typeof args[args.length - 1] == 'function'
  message = args.pop()
  vulnerable = args.pop()  if args.length > 0

  extendMove name, ->
    @beforeTurn = (battle, user) ->
      data = {vulnerable, message, condition}
      data.move = this
      user.attach(Attachment.Charging, data)

makeChargeMove 'Skull Bash', "$1 tucked in its head!"
makeChargeMove 'Razor Wind', "$1 whipped up a whirlwind!"
makeChargeMove 'Sky Attack', "$1 became cloaked in a harsh light!"
makeChargeMove 'Shadow Force', [], "$1 vanished instantly!"
makeChargeMove 'Ice Burn', [], "$1 became cloaked in freezing air!"
makeChargeMove 'Freeze Shock', [], "$1 became cloaked in a freezing light!"
makeChargeMove 'Fly', ["Gust", "Thunder", "Twister", "Sky Uppercut", "Hurricane", "Smack Down", "Whirlwind"], "$1 flew up high!"
makeChargeMove 'Bounce', ["Gust", "Thunder", "Twister", "Sky Uppercut", "Hurricane", "Smack Down", "Whirlwind"], "$1 sprang up!"
makeChargeMove 'Dig', ["Earthquake", "Magnitude"], "$1 burrowed its way under the ground!"
makeChargeMove 'Dive', ["Surf", "Whirlpool"], "$1 hid underwater!"
makeChargeMove 'SolarBeam', "$1 absorbed light!", (battle) ->
  battle.hasWeather(Weather.SUN)

extendMove 'SolarBeam', ->
  @basePower = (battle, user, target) ->
    if battle.hasWeather(Weather.RAIN) || battle.hasWeather(Weather.SAND) ||
        battle.hasWeather(Weather.HAIL)
      @power >> 1
    else
      @power


makeRechargeMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      user.attach(Attachment.Recharge)

makeMomentumMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      attachment = user.attach(Attachment.Momentum, move: this)
      attachment.turns += 1

    @basePower = (battle, user, target) ->
      times = user.get(Attachment.Momentum)?.layers || 0
      bp = @power * Math.pow(2, times)
      bp *= 2  if user.has(Attachment.DefenseCurl)
      bp

makeRevengeMove = (moveName) ->
  extendMove moveName, ->
    @basePower = (battle, user, target) ->
      hit = user.lastHitBy
      return @power  if !hit?
      {team, slot, move, turn} = hit
      pokemon = team.at(slot)
      if target == pokemon && !move.isNonDamaging() && battle.turn == turn
        2 * @power
      else
        @power

makeWeatherMove = (name, weatherType) ->
  extendMove name, ->
    @execute = (battle, user) ->
      if !battle.hasWeather(weatherType)
        @changeWeather(battle, user)
      else
        @fail(battle)

    @changeWeather = (battle, user) ->
      length = 5
      length = 8  if weatherType == user.getItem()?.lengthensWeather
      battle.setWeather(weatherType, length)

extendWithBoost = (name, boostTarget, boosts) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      pokemon = (if boostTarget == 'self' then user else target)
      pokemon.boost(boosts, user)

makeCounterMove = (name, multiplier, applies) ->
  extendMove name, ->
    @getTargets = (battle, user) ->
      # Return the last pokemon who hit this one, if it's alive.
      hit = user.lastHitBy
      if hit
        {team, slot} = hit
        pokemon = team.at(slot)
        return [ pokemon ]  if !pokemon.isFainted()

      # Return a random target (or none).
      pokemon = battle.getOpponents(user)
      pokemon = pokemon.filter((p) -> !p.isFainted())
      if pokemon.length == 0
        []
      else
        [ battle.rng.choice(pokemon) ]

    @calculateDamage = -> 0

    @afterSuccessfulHit = (battle, user, target) ->
      hit = user.lastHitBy
      if hit? && applies(hit.move) && hit.turn == battle.turn
        target.damage(multiplier * hit.damage, direct: false, source: "move")
      else
        @fail(battle)

makeTrappingMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      unless target.has(Attachment.Trap)
        turns = if !user.hasItem("Grip Claw")
          battle.rng.randInt(4, 5, "trapping move")
        else
          7

        target.attach(Attachment.Trap, user: user, moveName: name, turns: turns)
        user.attach(Attachment.TrapLeash, {target})

makeStatusCureMove 'Aromatherapy', 'A soothing aroma wafted through the area!'

extendMove 'Baton Pass', ->
  @execute = (battle, user, targets) ->
    slot = user.team.indexOf(user)
    if !battle.forceSwitch(user)
      @fail(battle)
      return

    # Copy!
    passable = user.attachments.getPassable()
    stages = _.clone(user.stages)
    attachments = user.attachments.attachments
    attachments = attachments.filter((a) -> a.constructor in passable)
    for attachment in passable
      user.unattach(attachment)
    user.team.attach(Attachment.BatonPass, {slot, stages, attachments})

makeTrappingMove "Bind"
makeRechargeMove 'Blast Burn'

extendMove 'Blizzard', ->
  @getAccuracy = (battle, user, target) ->
    return 0  if battle.hasWeather(Weather.HAIL)
    return @accuracy

makeMeanLookMove 'Block'
makePluckMove 'Bug Bite'

extendMove 'Camouflage', ->
  @use = (battle, user, target) ->
    # Camouflage changes type based on terrain
    # In Wi-Fi battles, the terrain always results in Ground type.
    target.types = [ "Ground" ]

extendMove 'Captivate', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if (!(user.gender == 'M' && target.gender == 'F') &&
        !(user.gender == 'F' && target.gender == 'M'))
      @fail(battle)
    else
      target.boost(specialAttack: -2, user)

extendMove 'Charge', ->
  oldUse = @use
  @use = (battle, user, target) ->
    user.unattach(Attachment.Charge)  # Charge can be used twice in a row
    user.attach(Attachment.Charge)
    battle.message "#{user.name} began charging power!"
    oldUse.call(this, battle, user, target)

extendMove 'Chip Away', ->
  oldExecute = @execute
  @execute = (battle, user, targets) ->
    target.attach(Attachment.ChipAway)  for target in targets
    oldExecute.call(this, battle, user, targets)
    target.unattach(Attachment.ChipAway)  for target in targets

makeRandomSwitchMove "Circle Throw"
makeTrappingMove "Clamp"

extendMove 'Clear Smog', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.resetBoosts()
    battle.cannedText('RESET_STATS', target)

extendWithBoost 'Close Combat', 'self', defense: -1, specialDefense: -1

extendMove 'Conversion', ->
  @use = (battle, user, target) ->
    {types, moves} = target
    moves = _.without(moves, battle.getMove(@name))
    # The original type of the move is used, not its generated type.
    moveTypes = moves.map((move) -> move.type)
    types = _.difference(moveTypes, types)
    type = battle.rng.choice(types, "conversion types")
    if !type?
      @fail(battle)
      return false
    target.types = [ type ]

extendMove 'Conversion 2', ->
  @use = (battle, user, target) ->
    {lastMove} = target
    if !lastMove?
      @fail(battle)
      return false

    moveType = lastMove.type
    possibles = []
    for type, value of util.Type
      possibles.push(type)  if util.typeEffectiveness(moveType, [ type ]) < 1
    user.types = [ battle.rng.choice(possibles, "conversion 2") ]

makeThiefMove 'Covet'

extendMove 'Defense Curl', ->
  oldUse = @use
  @use = (battle, user, target) ->
    oldUse.call(this, battle, user, target)
    target.attach(Attachment.DefenseCurl)

extendMove 'Defog', ->
  @entryHazards = [
    Attachment.Spikes
    Attachment.StealthRock
    Attachment.ToxicSpikes
  ]

  @selectPlayers = (battle, user, target) ->
    [ target ]

  @afterSuccessfulHit = (battle, user, target) ->
    target.boost(evasion: -1, user)
    target.team.unattach(Attachment.Reflect)
    target.team.unattach(Attachment.LightScreen)

    for pokemon in @selectPlayers(battle, user, target)
      for hazard in @entryHazards
        pokemon.team.unattach(hazard)

makeProtectMove 'Detect'
extendWithBoost 'Draco Meteor', 'self', specialAttack: -2
makeRandomSwitchMove "Dragon Tail"

extendMove 'Entrainment', ->
  bannedSourceAbilities =
    "Flower Gift": true
    "Forecast": true
    "Illusion": true
    "Imposter": true
    "Trace": true
    "Zen Mode": true

  @afterSuccessfulHit = (battle, user, target) ->
    if user.hasChangeableAbility() && user.ability.displayName not of bannedSourceAbilities && target.hasChangeableAbility() && target.ability.displayName != 'Truant'
      battle.cannedText('ACQUIRE_ABILITY', target, user.ability)
      target.copyAbility(user.ability)
    else
      @fail(battle)

makeEruptionMove 'Eruption'
makeExplosionMove 'Explosion'

extendMove 'Fake Out', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    if user.turnsActive > 1
      @fail(battle)
      return false

extendMove 'Feint', ->
  @afterSuccessfulHit = (battle, user, target) ->
    # TODO: Wide Guard
    if target.has(Attachment.Protect)
      target.unattach(Attachment.Protect)
      battle.message "#{target.name} fell for the feint!"

makeTrappingMove "Fire Spin"
makeOneHitKOMove 'Fissure'
makeReversalMove 'Flail'
extendMove 'Flame Wheel', -> @thawsUser = true
extendMove 'Flare Blitz', -> @thawsUser = true

extendMove 'Focus Energy', ->
  @use = (battle, user, target) ->
    if user.attach(Attachment.FocusEnergy)
      # TODO: Real message
      battle.message "#{user.name} began to focus!"
    else
      @fail(battle)
      false

extendMove 'Focus Punch', ->
  @beforeTurn = (battle, user) ->
    battle.message "#{user.name} is tightening its focus!"
    user.attach(Attachment.FocusPunch)

makeIdentifyMove("Foresight", ["Normal", "Fighting"])
makePickAttackMove 'Foul Play'
makeRechargeMove 'Frenzy Plant'
extendMove 'Fusion Flare', -> @thawsUser = true
makeRechargeMove 'Giga Impact'
makeWeightBased 'Grass Knot'
extendMove 'Growth', ->
  @use = (battle, user, target) ->
    boost = if battle.hasWeather(Weather.SUN) then 2 else 1
    user.boost(attack: boost, specialAttack: boost)

extendMove 'Grudge', ->
  @execute = (battle, user, targets) ->
    user.attach(Attachment.Grudge)
    battle.message "#{user.name} wants its target to bear a grudge!"

makeOneHitKOMove 'Guillotine'
extendWithBoost 'Hammer Arm', 'self', speed: -1
makeStatusCureMove 'Heal Bell', 'A bell chimed!'
makeRecoveryMove 'Heal Order'
makeRecoveryMove 'Heal Pulse'
makeWeightRatioBased 'Heat Crash'
makeWeightRatioBased 'Heavy Slam'
makeJumpKick 'Hi Jump Kick'
makeOneHitKOMove 'Horn Drill'
makeRechargeMove 'Hydro Cannon'
makeRechargeMove 'Hyper Beam'
makeMomentumMove 'Ice Ball'
makeWeatherMove 'Hail', Weather.HAIL

extendMove 'Hurricane', ->
  @getAccuracy = (battle, user, target) ->
    return 50  if battle.hasWeather(Weather.SUN)
    return 0   if battle.hasWeather(Weather.RAIN)
    return @accuracy

makeJumpKick 'Jump Kick'
extendWithBoost 'Leaf Storm', 'self', specialAttack: -2

extendMove 'Leech Seed', ->
  oldWillMiss = @willMiss
  @willMiss = (battle, user, target) ->
    if target.hasType("Grass")
      true
    else
      oldWillMiss.call(this, battle, user, target)

makeLockOnMove 'Lock-On'
makeWeightBased 'Low Kick'

extendMove 'Lucky Chant', ->
  @execute = (battle, user, opponents) ->
    if user.team.attach(Attachment.LuckyChant)
      battle.message "The Lucky Chant shielded #{battle.getOwner(user)}'s " +
                     "team from critical hits!"
    else
      @fail(battle)

makeTrappingMove "Magma Storm"
makeMeanLookMove 'Mean Look'
makeRecoveryMove 'Milk Drink'
makeLockOnMove 'Mind Reader'

extendMove 'Minimize', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Minimize)

makeIdentifyMove("Miracle Eye", ["Psychic"])

extendMove 'Mirror Move', ->
  @execute = (battle, user, targets) ->
    target = targets[0]
    move = target.lastMove
    if !move? || !move.hasFlag("mirror")
      @fail(battle)
      return false
    battle.executeMove(move, user, targets)

makeWeatherRecoveryMove 'Moonlight'
makeWeatherRecoveryMove 'Morning Sun'
makeLevelAsDamageMove 'Night Shade'
makeIdentifyMove("Odor Sleuth", ["Normal", "Fighting"])
extendWithBoost 'Overheat', 'self', specialAttack: -2
makePluckMove 'Pluck'
makeProtectMove 'Protect'
extendWithBoost 'Psycho Boost', 'self', specialAttack: -2
makePickDefenseMove 'Psyshock'
makePickDefenseMove 'Psystrike'
makeBasePowerBoostMove 'Punishment', 60, 200, 'target'
makeWeatherMove 'Rain Dance', Weather.RAIN
makeRecoveryMove 'Recover'

extendMove 'Refresh', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if !target.cureStatus()
      @fail(battle)

makeRevengeMove 'Revenge'
makeReversalMove 'Reversal'
makeRandomSwitchMove "Roar"
makeRechargeMove 'Roar of Time'
makeRechargeMove 'Rock Wrecker'
makeMomentumMove 'Rollout'

makeRecoveryMove 'Roost'
extendMove 'Roost', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.attach(Attachment.Roost)

extendMove 'Sacred Fire', -> @thawsUser = true
makeWeatherMove 'Sandstorm', Weather.SAND
makeTrappingMove "Sand Tomb"
extendMove 'Scald', -> @thawsUser = true
makePickDefenseMove 'Secret Sword'
makeExplosionMove 'Selfdestruct'
makeLevelAsDamageMove 'Seismic Toss'
makeOneHitKOMove 'Sheer Cold'
makeRecoveryMove 'Slack Off'
makeRecoveryMove 'Softboiled'
makeMeanLookMove 'Spider Web'

extendMove 'Spit Up', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !user.has(Attachment.Stockpile)
      @fail(battle)
      return false
    oldUse.call(this, battle, user, target)

  @basePower = (battle, user, target) ->
    attachment = user.get(Attachment.Stockpile)
    layers = attachment?.layers || 0
    100 * layers

  oldExecute = @execute
  @execute = (battle, user, targets) ->
    oldExecute.call(this, battle, user, targets)
    attachment = user.get(Attachment.Stockpile)
    return  if !attachment?
    num = -attachment.layers
    user.unattach(Attachment.Stockpile)
    user.boost(defense: num, specialDefense: num)

makeStompMove 'Steamroller'

extendMove 'Stockpile', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if user.attach(Attachment.Stockpile)
      user.boost(defense: 1, specialDefense: 1)
    else
      @fail(battle)

makeStompMove 'Stomp'
makeBasePowerBoostMove 'Stored Power', 20, 860, 'user'
makeWeatherMove 'Sunny Day', Weather.SUN
extendWithBoost 'Superpower', 'self', attack: -1, defense: -1

extendMove 'Swallow', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !user.has(Attachment.Stockpile)
      @fail(battle)
      return false
    oldUse.call(this, battle, user, target)

  @afterSuccessfulHit = (battle, user, target) ->
    {layers} = target.get(Attachment.Stockpile)
    amount = util.roundHalfDown(target.stat('hp') / Math.pow(2, 3 - layers))
    # Swallow is not a draining move, so it is not affected by Big Root.
    target.heal(amount)

  oldExecute = @execute
  @execute = (battle, user, targets) ->
    oldExecute.call(this, battle, user, targets)
    for target in targets
      attachment = target.get(Attachment.Stockpile)
      return  if !attachment?
      num = -attachment.layers
      target.unattach(Attachment.Stockpile)
      user.boost(defense: num, specialDefense: num)

makeTrickMove 'Switcheroo'
extendMove 'Super Fang', ->
  @calculateDamage = (battle, user, target) ->
    halfHP = Math.floor(target.currentHP / 2)
    Math.max(1, halfHP)
makeWeatherRecoveryMove 'Synthesis'
extendMove 'Teleport', ->
  @execute = (battle) -> @fail(battle)
makeThiefMove 'Thief'

extendMove 'Thunder', ->
  @getAccuracy = (battle, user, target) ->
    return 50  if battle.hasWeather(Weather.SUN)
    return 0   if battle.hasWeather(Weather.RAIN)
    return @accuracy

extendMove 'Thunder Wave', ->
  @ignoresImmunities = -> false

makeTrickMove 'Trick'
extendWithBoost 'V-create', 'self', defense: -1, specialDefense: -1, speed: -1
makeEruptionMove 'Water Spout'
makeRandomSwitchMove "Whirlwind"
makeTrappingMove "Wrap"

extendMove 'Assist', ->
  bannedMoves =
    "Assist":       true
    "Bestow":       true
    "Chatter":      true
    "Circle Throw": true
    'Copycat':      true
    "Counter":      true
    "Covet":        true
    "Destiny Bond": true
    "Detect":       true
    "Dragon Tail":  true
    "Endure":       true
    "Feint":        true
    "Focus Punch":  true
    "Follow Me":    true
    "Helping Hand": true
    "Me First":     true
    "Metronome":    true
    "Mimic":        true
    "Mirror Coat":  true
    "Mirror Move":  true
    "Nature Power": true
    "Protect":      true
    "Rage Powder":  true
    "Sketch":       true
    "Sleep Talk":   true
    "Snatch":       true
    "Struggle":     true
    "Switcheroo":   true
    "Thief":        true
    "Transform":    true
    "Trick":        true
  @execute = (battle, user) ->
    pokemon = _.without(user.team.pokemon, user)
    moves   = _.flatten(pokemon.map((p) -> p.moves))
    moves   = moves.filter((move) -> move.name not of bannedMoves)
    if moves.length == 0
      @fail(battle)
    else
      move = battle.rng.choice(moves, "assist")
      battle.executeMove(move, user, battle.getTargets(move, user))

extendMove 'Aqua Ring', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.AquaRing)
    battle.message "#{target.name} surrounded itself with a veil of water!"

extendMove 'Assurance', ->
  @basePower = (battle, user, target) ->
    hit = user.lastHitBy
    if hit?.turn == battle.turn && !hit.move.isNonDamaging()
      2 * @power
    else
      @power

extendMove 'Autotomize', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Autotomize)

makeRevengeMove 'Avalanche'

extendMove 'Acrobatics', ->
  @basePower = (battle, user, target) ->
    if !user.hasItem() then 2 * @power else @power

extendMove 'Acupressure', ->
  @use = (battle, user, target) ->
    stats = (stat  for stat, num of target.stages when num < 6)
    if stats.length > 0
      randomStat = battle.rng.choice(stats)
      hash = {}
      hash[randomStat] = 2
      target.boost(hash)
    else
      @fail(battle)
      return false

extendMove 'Beat Up', ->
  @calculateNumberOfHits = (battle, user, target) ->
    teamIndex = user.team.indexOf(user)
    numHits = 0
    for p, i in user.team.pokemon
      if teamIndex == i || (!p.hasStatus() && !p.isFainted())
        numHits++
    numHits

  @basePower = (battle, user, target, hitNumber=1) ->
    index = -1
    {team} = user
    teamIndex = team.indexOf(user)
    for x in [0...hitNumber]
      index++
      while index != teamIndex &&
          (team.at(index).hasStatus() || team.at(index).isFainted())
        index++
    5 + Math.floor(team.at(index).baseStats.attack / 10)

extendMove 'Belly Drum', ->
  @use = (battle, user, target) ->
    halfHP = Math.floor(user.stat('hp') / 2)
    if user.currentHP <= halfHP || !user.boost(attack: 12)
      @fail(battle)
      return false
    else
      user.damage(halfHP, source: "move")

extendMove 'Brick Break', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    target.team.unattach(Attachment.Reflect)
    target.team.unattach(Attachment.LightScreen)

extendMove 'Brine', ->
  @basePower = (battle, user, target) ->
    if target.currentHP <= Math.floor(target.stat('hp') / 2)
      2 * @power
    else
      @power

extendMove 'Copycat', ->
  @execute = (battle, user, targets) ->
    move = battle.lastMove
    if move? && move != battle.getMove('Copycat')
      battle.executeMove(move, user, battle.getTargets(move, user))
    else
      @fail(battle)


makeCounterMove('Counter', 2, (move) -> move.isPhysical())
makeCounterMove('Mirror Coat', 2, (move) -> move.isSpecial())
makeCounterMove('Metal Burst', 1.5, (move) -> move.isPhysical() || move.isSpecial())

extendMove 'Crush Grip', ->
  @basePower = (battle, user, target) ->
    1 + Math.floor(120 * target.currentHP / target.stat('hp'))

extendMove 'Curse', ->
  @getTargets = (battle, user) ->
    pokemon = battle.getOpponents(user)
    [ battle.rng.choice(pokemon, "random opponent") ]

  @execute = (battle, user, targets) ->
    if !user.hasType("Ghost")
      user.boost(attack: 1, defense: 1, speed: -1)
      return

    user.damage(Math.floor(user.stat('hp') / 2), source: "move")
    for target in targets
      target.attach(Attachment.Curse)
      battle.message "#{user.name} cut its own HP and laid a curse on #{target.name}!"

extendMove 'Destiny Bond', ->
  @hit = (battle, user) ->
    user.attach(Attachment.DestinyBond)

makeDelayedAttackMove("Doom Desire", "$1 chose Doom Desire as its destiny!")

extendMove 'Dragon Rage', ->
  @calculateDamage = (battle, user, target) ->
    40

extendMove 'Dream Eater', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !target.has(Status.Sleep)
      @fail(battle)
      return false
    oldUse.call(this, battle, user, target)

extendMove 'Echoed Voice', ->
  @basePower = (battle, user, target) ->
    layers = battle.get(Attachment.EchoedVoice)?.layers || 0
    @power * (layers + 1)

  @afterSuccessfulHit = (battle, user, target) ->
    battle.attach(Attachment.EchoedVoice)
    attachment = battle.get(Attachment.EchoedVoice)
    attachment.turns = 2

extendMove 'Electro Ball', ->
  @basePower = (battle, user, target) ->
    ratio = user.stat('speed') / target.stat('speed')
    power = 0
    if ratio >= 4
      power = 150
    else if ratio >= 3
      power = 120
    else if ratio >= 2
      power = 80
    else if ratio >= 1
      power = 60
    else
      power = 40

extendMove 'Encore', ->
  bannedMoves =
    'Encore': true
    'Mimic': true
    'Mirror Move': true
    'Sketch': true
    'Struggle': true
    'Transform': true
  @afterSuccessfulHit = (battle, user, target) ->
    if !target.lastMove?
      @fail(battle)
    else if target.lastMove.name of bannedMoves
      @fail(battle)
    else if target.pp(target.lastMove) == 0
      @fail(battle)
    else if target.attach(Attachment.Encore)
      if battle.willMove(target)
        battle.changeMove(target, target.lastMove)
    else
      @fail(battle)

extendMove 'Endeavor', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    if target.currentHP < user.currentHP
      @fail(battle)
      return false

  @calculateDamage = (battle, user, target) ->
    target.currentHP - user.currentHP

makeProtectCounterMove 'Endure', (battle, user, targets) ->
  battle.message "#{user.name} braced itself!"
  user.attach(Attachment.Endure)

extendMove 'Facade', ->
  @basePower = (battle, user, target) ->
    if user.hasStatus()
      2 * @power
    else
      @power

extendMove 'False Swipe', ->
  @oldCalculateDamage = @calculateDamage
  @calculateDamage = (battle, user, target, hitNumber, isDirect) ->
    damage = @oldCalculateDamage(battle, user, target, hitNumber, isDirect)
    if damage >= target.currentHP && isDirect
      damage = target.currentHP - 1
    damage

extendMove 'Final Gambit', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.faint()

  @calculateDamage = (battle, user, target) ->
    user.currentHP

extendMove 'Flatter', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Confusion, {battle})
    target.boost(specialAttack: 1, user)

extendMove 'Fling', ->
  @beforeTurn = (battle, user) ->
    user.attach(Attachment.Fling)

  oldUse = @use
  @use = (battle, user, target) ->
    fling = user.get(Attachment.Fling)
    if !fling?.item
      @fail(battle)
      return false

    oldUse.call(this, battle, user, target)

  @afterSuccessfulHit = (battle, user, target) ->
    {item} = user.get(Attachment.Fling)
    switch item.displayName
      when "Poison Barb"
        target.attach(Status.Poison)
      when "Light Ball"
        target.attach(Status.Paralyze)
      when "Flame Orb"
        target.attach(Status.Burn)
      when "Toxic Orb"
        target.attach(Status.Toxic)
      when "King's Rock", "Razor Fang"
        target.attach(Attachment.Flinch)
      when "Mental Herb", "White Herb"
        item.activate(battle, target)
      else
        item.eat(battle, target)  if item.type == "berries"

  @basePower = (battle, user, target) ->
    fling = user.get(Attachment.Fling)
    fling.item.flingPower

extendMove 'Frustration', ->
  @basePower = -> 102

extendMove 'Fury Cutter', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.attach(Attachment.FuryCutter, move: this)

  @basePower = (battle, user, target) ->
    attachment = user.get(Attachment.FuryCutter)
    layers = attachment?.layers || 0
    @power * Math.pow(2, layers)

makeDelayedAttackMove("Future Sight", "$1 foresaw an attack!")

extendMove 'Gastro Acid', ->
  @use = (battle, user, target) ->
    if !target.attach(Attachment.AbilitySuppress)
      @fail(battle)
      return false

    battle.message "#{target.name}'s ability was suppressed!"

extendMove 'Gravity', ->
  @execute = (battle, user, targets) ->
    if !battle.attach(Attachment.Gravity)
      @fail(battle)
      return
    battle.message "Gravity intensified!"
    for target in targets
      target.attach(Attachment.GravityPokemon)
      target.unattach(Attachment.MagnetRise)
      target.unattach(Attachment.Telekinesis)
      charging = target.get(Attachment.Charging)
      target.unattach(Attachment.Charging)  if charging?.move.hasFlag("gravity")

extendMove 'Guard Swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    for stat in [ 'defense', 'specialDefense' ]
      stats = [ target.stages[stat], user.stages[stat] ]
      [ user.stages[stat], target.stages[stat] ] = stats

extendMove 'Gyro Ball', ->
  @basePower = (battle, user, target) ->
    power = 1 + Math.floor(25 * target.stat('speed') / user.stat('speed'))
    Math.min(150, power)

extendMove 'Haze', ->
  @execute = (battle, user, targets) ->
    user.resetBoosts()
    for target in targets
      target.resetBoosts()
    battle.cannedText('RESET_ALL_STATS')

extendMove 'Heart Swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    [user.stages, target.stages] = [target.stages, user.stages]
    battle.message "#{user.name} switched stat changes with the target!"

extendMove 'Hex', ->
  @basePower = (battle, user, target) ->
    if target.hasStatus()
      2 * @power
    else
      @power

extendMove 'Hidden Power', ->
  @basePower = (battle, user, target) ->
    ivs =
      hp: user.iv('hp')
      attack: user.iv('attack')
      defense: user.iv('defense')
      speed: user.iv('speed')
      specialAttack: user.iv('specialAttack')
      specialDefense: user.iv('specialDefense')
    HiddenPower.BW.basePower(ivs)

  @getType = (battle, user, target) ->
    ivs =
      hp: user.iv('hp')
      attack: user.iv('attack')
      defense: user.iv('defense')
      speed: user.iv('speed')
      specialAttack: user.iv('specialAttack')
      specialDefense: user.iv('specialDefense')
    HiddenPower.BW.type(ivs)

extendMove 'Imprison', ->
  @hit = (battle, user, target) ->
    {moves} = target
    if target.attach(Attachment.Imprison, {battle, moves})
      battle.message "#{target.name} sealed the opponent's moves!"
    else
      @fail(battle)

extendMove 'Incinerate', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasItem() && target.getItem().type == 'berries'
      battle.message "#{target.name}'s #{target.getItem().name} was burnt up!"
      target.removeItem()

extendMove 'Judgment', ->
  @getType = (battle, user, target) ->
    user.getItem()?.plate || @type

extendMove 'Knock Off', ->
  @afterSuccessfulHit = (battle, user, target, damage, isDirect) ->
    if user.isAlive() && target.hasItem() && target.canLoseItem() && isDirect
      battle.message "#{user.name} knocked off #{target.name}'s #{target.getItem().displayName}!"
      target.removeItem()

extendMove 'Last Resort', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if this not in user.moves || user.moves.length <= 1
      @fail(battle)
      return false
    for moveName in _.without(user.moves, this).map((m) -> m.name)
      if moveName not of user.used
        @fail(battle)
        return false
    oldUse.call(this, battle, user, target)

extendMove 'Light Screen', ->
  @execute = (battle, user, opponents) ->
    if !user.team.attach(Attachment.LightScreen, {user})
      @fail(battle)

extendMove 'Healing Wish', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.team.getAliveBenchedPokemon().length > 0
      target.faint()
      target.team.attach(Attachment.HealingWish)
    else
      @fail(battle)

extendMove 'Lunar Dance', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.team.getAliveBenchedPokemon().length > 0
      target.faint()
      target.team.attach(Attachment.LunarDance)
    else
      @fail(battle)

extendMove 'Magic Coat', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.MagicCoat)
    target.team.attach(Attachment.MagicCoat)

extendMove 'Magnet Rise', ->
  @use = (battle, user, target) ->
    if target.attach(Attachment.MagnetRise)
      battle.message "#{target.name} is now floating in the air!"
    else
      @fail(battle)
      return false

extendMove 'Magnitude', ->
  @basePower = (battle, user, target) ->
    rand = battle.rng.randInt(0, 99, "magnitude")
    magnitude = 0
    power = 0
    if rand < 5
      power = 10
      magnitude = 4
    else if rand < 15
      power = 30
      magnitude = 5
    else if rand < 35
      power = 50
      magnitude = 6
    else if rand < 65
      power = 70
      magnitude = 7
    else if rand < 85
      power = 90
      magnitude = 8
    else if rand < 95
      power = 110
      magnitude = 9
    else
      power = 150
      magnitude = 10

    battle.message "Magnitude #{magnitude}!"
    power

extendMove 'Me First', ->
  bannedMoves = {
    "Chatter"    : true
    "Counter"    : true
    "Covet"      : true
    "Focus Punch": true
    "Me First"   : true
    "Metal Burst": true
    "Mirror Coat": true
    "Struggle"   : true
    "Thief"      : true
  }
  @execute = (battle, user, targets) ->
    target = targets[0]  # Me First is a single-target move
    m = battle.peekMove(target)
    if !battle.willMove(target) || m.isNonDamaging() || bannedMoves[m.name]
      @fail(battle)
      return false
    user.attach(Attachment.MeFirst)
    battle.executeMove(m, user, targets)

extendMove 'Memento', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.boost(attack: -2, specialAttack: -2, user)
    user.faint()

extendMove 'Metronome', ->
  impossibleMoves =
    "After You": true
    "Assist": true
    "Bestow": true
    'Chatter': true
    "Copycat": true
    "Counter": true
    "Covet": true
    "Destiny Bond": true
    "Detect": true
    "Endure": true
    "Feint": true
    "Focus Punch": true
    "Follow Me": true
    "Freeze Shock": true
    "Helping Hand": true
    "Ice Burn": true
    "Me First": true
    "Mimic": true
    "Mirror Coat": true
    "Mirror Move": true
    "Nature Power": true
    "Protect": true
    "Quash": true
    "Quick Guard": true
    "Rage Powder": true
    "Relic Song": true
    "Secret Sword": true
    "Sketch": true
    "Sleep Talk": true
    "Snatch": true
    "Snarl": true
    "Snore": true
    "Struggle": true
    "Switcheroo": true
    "Techno Blast": true
    "Thief": true
    "Transform": true
    "Trick": true
    "V-create": true
    "Wide Guard": true

  for move of impossibleMoves
    if move not of Moves
      throw new Error("The illegal Metronome move '#{move}' does not exist.")

  @execute = (battle, user, targets) ->
    index = battle.rng.randInt(0, MoveList.length - 1, "metronome")
    while MoveList[index].name of impossibleMoves || MoveList[index] in user.moves
      index = battle.rng.randInt(0, MoveList.length - 1, "metronome reselect")
    move = MoveList[index]
    battle.message "Waggling a finger let it use #{move.name}!"

    # Determine new targets
    if move.target == 'selected-pokemon'
      pokemon = battle.getOpponents(user)
      targets = [ battle.rng.choice(pokemon) ]
    else
      targets = battle.getTargets(move, user)
    battle.executeMove(move, user, targets)

extendMove 'Natural Gift', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !user.hasItem() || user.isItemBlocked() || !user.getItem().naturalGift
      @fail(battle)
      return false

    oldUse.call(this, battle, user, target)

  @basePower = (battle, user, target) ->
    item = user.getItem()
    item.naturalGift.power

  @getType = (battle, user, target) ->
    item = user.getItem()
    item.naturalGift.type

  @afterSuccessfulHit = (battle, user, target) ->
    user.removeItem()

extendMove 'Nature Power', ->
  @execute = (battle, user, targets) ->
    # In Wi-Fi battles, Earthquake is always chosen.
    battle.message "#{@name} turned into Earthquake!"
    earthquake = battle.getMove('Earthquake')
    battle.executeMove(earthquake, user, targets)

  @getTargets = (battle, user) ->
    earthquake = battle.getMove('Earthquake')
    battle.getTargets(earthquake, user)

extendMove 'Pain Split', ->
  @afterSuccessfulHit = (battle, user, target) ->
    averageHP = Math.floor((user.currentHP + target.currentHP) / 2)
    user.setHP(averageHP)
    target.setHP(averageHP)
    battle.message "The battlers shared their pain!"

extendMove 'Pay Day', ->
  @afterSuccessfulHit = (battle, user, target) ->
    battle.message "Coins were scattered everywhere!"

extendMove 'Payback', ->
  @basePower = (battle, user, target) ->
    if !target.lastMove? || battle.willMove(target)
      @power
    else
      2 * @power

extendMove 'Power Swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    for stat in [ 'attack', 'specialAttack' ]
      stats = [ target.stages[stat], user.stages[stat] ]
      [ user.stages[stat], target.stages[stat] ] = stats

extendMove 'Present', ->
  @basePower = (battle, user, target) ->
    user.get(Attachment.Present).power

  @afterSuccessfulHit = (battle, user, target) ->
    if user.get(Attachment.Present).power == 0
      amount = target.stat('hp') >> 2
      target.heal(amount)

  oldExecute = @execute
  @execute = (battle, user, targets) ->
    chance = battle.rng.next("present")
    power  = if chance < .1
               120
             else if chance < .3
               0
             else if chance < .6
               80
             else
               40
    user.attach(Attachment.Present, {power})
    oldExecute.call(this, battle, user, targets)

extendMove 'Psywave', ->
  @calculateDamage = (battle, user, target) ->
    fraction = battle.rng.randInt(5, 15, "psywave") / 10
    Math.floor(user.level * fraction)

extendMove 'Psych Up', ->
  @use = (battle, user, target) ->
    for stage, value of target.stages
      user.stages[stage] = value
    battle.message "#{user.name} copied #{target.name}'s stat changes!"

extendMove 'Psycho Shift', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if !user.hasStatus() || target.hasStatus()
      @fail(battle)
      return false
    status = user.status
    user.cureStatus()
    target.attach(status)

extendMove 'Pursuit', ->
  @beforeTurn = (battle, user) ->
    user.attach(Attachment.Pursuit)

  @basePower = (battle, user, target) ->
    if user.has(Attachment.PursuitModifiers)
      2 * @power
    else
      @power

extendMove 'Rage', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.attach(Attachment.Rage)

extendMove 'Rapid Spin', ->
  @entryHazards = [ Attachment.Spikes, Attachment.StealthRock, Attachment.ToxicSpikes ]
  @afterSuccessfulHit = (battle, user) ->
    # Do not remove anything if the user is fainted.
    if user.isFainted()
      return

    team = user.team

    for hazard in @entryHazards
      team.unattach(hazard)

    # Remove trapping moves like fire-spin
    user.unattach(Attachment.Trap)

    # Remove leech seed
    user.unattach(Attachment.LeechSeed)

extendMove 'Reflect', ->
  @execute = (battle, user, opponents) ->
    if !user.team.attach(Attachment.Reflect, {user})
      @fail(battle)

extendMove 'Reflect Type', ->
  @use = (battle, user, target) ->
    if user.hasAbility("Multitype")
      @fail(battle)
      return false

    user.types = target.types
    battle.message "#{user.name}'s type changed to match #{target.name}'s!"

extendMove 'Relic Song', ->
  @afterSuccessfulHit = (battle, user, target) ->
    return  if user.name != 'Meloetta'

    if user.isInForme("default")
      user.changeForme("pirouette")
    else
      user.changeForme("default")

    battle.cannedText('TRANSFORM', user)

extendMove 'Rest', ->
  @hit = (battle, user, target) ->
    if user.currentHP >= user.stat('hp') || user.has(Status.Sleep) ||
        !user.attach(Status.Sleep, turns: 2, force: true)
      @fail(battle)
      return
    user.setHP(user.stat('hp'))

extendMove 'Retaliate', ->
  @basePower = (battle, user, target) ->
    if user.team.faintedLastTurn
      140
    else
      70

extendMove 'Return', ->
  @basePower = -> 102

extendMove 'Role Play', ->
  bannedAbilities =
    "Flower Gift": true
    "Forecast": true
    "Illusion": true
    'Imposter': true
    "Trace": true
    "Wonder Guard": true
    "Zen Mode": true

  @afterSuccessfulHit = (battle, user, target) ->
    if user.hasChangeableAbility() && target.hasChangeableAbility() && target.ability.displayName not of bannedAbilities && user.ability != target.ability
      battle.message "#{user.name} copied #{target.name}'s #{target.ability.displayName}!"
      user.copyAbility(target.ability)
    else
      @fail(battle)

extendMove 'Simple Beam', ->
  bannedAbilities =
    "Simple": true
    "Truant": true

  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasChangeableAbility() && target.ability.displayName not of bannedAbilities
      battle.cannedText('ACQUIRE_ABILITY', target, 'Simple')
      target.copyAbility(Ability.Simple)
    else
      @fail(battle)

extendMove 'Sleep Talk', ->
  bannedMoves = [
    "Assist"
    "Bide"
    "Chatter"
    "Copycat"
    "Focus Punch"
    "Me First"
    "Metronome"
    "Mimic"
    "Mirror Move"
    "Nature Power"
    "Sketch"
    "Sleep Talk"
    "Uproar"
  ]
  @usableWhileAsleep = true
  @execute = (battle, user) ->
    viableMoves = user.moves.filter((move) -> move.name not in bannedMoves)
    if viableMoves.length == 0 || !user.has(Status.Sleep)
      @fail(battle)
      return
    moveIndex = battle.rng.randInt(0, viableMoves.length - 1, "sleep talk")
    move = viableMoves[moveIndex]
    battle.executeMove(move, user, battle.getTargets(move, user))

extendMove 'Smack Down', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.SmackDown)
    target.unattach(Attachment.MagnetRise)
    target.unattach(Attachment.Telekinesis)
    # Smack Down will miss on charge moves it cannot hit.
    target.unattach(Attachment.Charging)

makeStatusCureAttackMove 'SmellingSalt', Status.Paralyze

extendMove 'Snore', ->
  @usableWhileAsleep = true
  oldUse = @use
  @use = (battle, user, target) ->
    if !user.has(Status.Sleep)
      @fail(battle)
      return false
    else
      oldUse.call(this, battle, user, target)

extendMove 'Soak', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if (target.types.length == 1 && target.types[0] == 'Water') || target.name == 'Arceus'
      @fail(battle)
    else
      target.types = [ 'Water' ]
      battle.cannedText('TRANSFORM_TYPE', target, 'Water')

extendMove 'SonicBoom', ->
  @calculateDamage = (battle, user, target) ->
    20

makeOpponentFieldMove 'Spikes', (battle, user, opponentId) ->
  team = battle.getTeam(opponentId)
  if !team.attach(Attachment.Spikes)
    @fail(battle)

extendMove 'Spite', ->
  @execute = (battle, user, opponents) ->
    for opponent in opponents
      move = opponent.lastMove
      if !move || !opponent.knows(move) || opponent.pp(move) == 0
        @fail(battle)
        return
      opponent.reducePP(move, 4)
      battle.message "It reduced the PP of #{opponent.name}!"

makeOpponentFieldMove 'Stealth Rock', (battle, user, opponentId) ->
  team = battle.getTeam(opponentId)
  if !team.attach(Attachment.StealthRock)
    @fail(battle)

extendMove 'Struggle', ->
  @type = '???'

  @typeEffectiveness = -> 1

  @afterSuccessfulHit = (battle, user, target) ->
    user.damage(user.stat('hp') >> 2, source: "move")

extendMove 'Splash', ->
  @execute = (battle, user, target) ->
    battle.message "But nothing happened!"

extendMove 'Substitute', ->
  @execute = (battle, user, targets) ->
    dmg = user.stat('hp') >> 2
    if dmg >= user.currentHP || dmg == 0
      battle.cannedText('SUBSTITUTE_WEAK')
      @fail(battle)
      return

    if user.has(Attachment.Substitute)
      battle.cannedText('SUBSTITUTE_EXISTS', user)
      @fail(battle)
      return

    user.damage(dmg, source: "move")
    user.attach(Attachment.Substitute, hp: dmg, battle: battle)
    battle.cannedText('SUBSTITUTE_START', user)

  @fail = (battle) ->

extendMove 'Sucker Punch', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !battle.willMove(target) || battle.peekMove(target).isNonDamaging()
      @fail(battle)
      return false
    else
      oldUse.call(this, battle, user, target)

extendMove 'Swagger', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Confusion, {battle})
    target.boost(attack: 2, user)

extendMove 'Synchronoise', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if _.every(user.types, (type) -> type not in target.types)
      @fail(battle)
      return false
    return oldUse.call(this, battle, user, target)

extendMove 'Tailwind', ->
  @execute = (battle, user, targets) ->
    team = user.team
    if team.has(Attachment.Tailwind)
      @fail(battle)
      return false

    team.attach(Attachment.Tailwind)
    battle.message "A tailwind started blowing!"

extendMove 'Taunt', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if !target.attach(Attachment.Taunt, battle)
      @fail(battle)

extendMove 'Techno Blast', ->
  @getType = (battle, user, target) ->
    switch user.getItem()?.displayName
      when "Burn Drive"
        "Fire"
      when "Chill Drive"
        "Ice"
      when "Douse Drive"
        "Water"
      when "Shock Drive"
        "Electric"
      else
        "Normal"

makeOpponentFieldMove 'Toxic Spikes', (battle, user, opponentId) ->
  team = battle.getTeam(opponentId)
  if !team.attach(Attachment.ToxicSpikes)
    @fail(battle)

extendMove 'Transform', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if !user.attach(Attachment.Transform, {target})
      @fail(battle)
      return false
    battle.cannedText('TRANSFORM_INTO', user, target)

extendMove 'Trick Room', ->
  @execute = (battle, user, targets) ->
    if battle.attach(Attachment.TrickRoom)
      battle.cannedText('TRICK_ROOM_START', user)
    else
      battle.unattach(Attachment.TrickRoom)

extendMove 'Trump Card', ->
  @basePower = (battle, user, target) ->
    switch user.pp(this)
      when 3
        50
      when 2
        60
      when 1
        80
      when 0
        200
      else
        40

makeSwitchMove = (moveName) ->
  extendMove moveName, ->
    @afterSuccessfulHit = (battle, user, target) ->
      battle.forceSwitch(user)

makeSwitchMove 'U-turn'

extendMove 'Venoshock', ->
  @basePower = (battle, user, target) ->
    if target.has(Status.Toxic) || target.has(Status.Poison)
      2 * @power
    else
      @power

makeSwitchMove 'Volt Switch'

makeStatusCureAttackMove 'Wake-Up Slap', Status.Sleep

extendMove 'Weather Ball', ->
  @getType = (battle, user, target) ->
    if      battle.hasWeather(Weather.SUN)  then 'Fire'
    else if battle.hasWeather(Weather.RAIN) then 'Water'
    else if battle.hasWeather(Weather.HAIL) then 'Ice'
    else if battle.hasWeather(Weather.SAND) then 'Rock'
    else 'Normal'

  @basePower = (battle, user, target) ->
    if battle.hasWeather(Weather.NONE) then 50 else 100


extendMove 'Wish', ->
  @hit = (battle, user) ->
    @fail(battle)  unless user.team.attach(Attachment.Wish, {user})

extendMove 'Worry Seed', ->
  bannedAbilities =
    "Insomnia": true
    "Truant": true

  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasChangeableAbility() && target.ability.displayName not of bannedAbilities
      battle.cannedText('ACQUIRE_ABILITY', target, 'Insomnia')
      target.copyAbility(Ability.Insomnia)
    else
      @fail(battle)

extendMove 'Wring Out', ->
  @basePower = (battle, user, target) ->
    power = Math.floor(120 * user.currentHP / user.stat('hp'))
    Math.max(1, power)

# Keep this at the bottom or look up how it affects Metronome.
# TODO: Figure out a better solution
Moves['Confusion Recoil'] = new Move "Confusion recoil",
  "accuracy": 0,
  "damage": "physical",
  "power": 40,
  "priority": 0,
  "type": "???"

# Confusion never crits
extendMove 'Confusion Recoil', ->
  @isCriticalHit = -> false

Moves['Recharge'] = new Move("Recharge", target: "user")

# After everything to ensure that basePower is overridden last.
makeVulnerable = (moveName, byMove) ->
  extendMove byMove, ->
    oldBasePower = @basePower
    @basePower = (battle, user, target) ->
      power    = oldBasePower.call(this, battle, user, target)
      charging = target.get(Attachment.Charging)
      return power  if !charging?

      if charging.move == battle.getMove(moveName) then 2 * power else power

makeVulnerable('Fly', 'Gust')
makeVulnerable('Fly', 'Twister')
makeVulnerable('Bounce', 'Gust')
makeVulnerable('Bounce', 'Twister')
makeVulnerable('Dig', 'Earthquake')
makeVulnerable('Dig', 'Magnitude')
makeVulnerable('Dive', 'Surf')
makeVulnerable('Dive', 'Whirlpool')
