@MoveData = require('./data_moves.json')
{Weather} = require('../../server/weather')
{Move} = require('../../server/move')
{Status} = require('../../server/status')
{Attachment} = require('../../server/attachment')
{_} = require 'underscore'
util = require '../../server/util'

# Generate the initial versions of every single move.
# Many will be overwritten later.
@moves = moves = {}
@moveList = moveList = []
for name, attributes of @MoveData
  @moves[name] = new Move(name, attributes)
  @moveList.push(name)

# Extends a move in the move list using a callback.
#
# name -      The name of the move to extend.
# callback -  The function that will extend the move. 'this'
#             is the move object itself.
#
# Example:
#
#   extendMove 'substitute', (attributes) ->
#     @initialize -> # blah
#     @afterMove -> # blah
#
extendMove = (name, callback) ->
  if name not of moves
    throw new Error("Cannot extend Move '#{name}' because it does not exist.")

  move = moves[name]
  callback.call(move, move.attributes)

extendWithPrimaryEffect = (name, Klass, options={}) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if target.hasAttachment(Klass)
        # TODO: Placeholder
        @fail(battle)
        return

      hash = _.clone(options)
      hash.battle = battle
      target.attach(Klass, hash)

extendWithPrimaryStatus = (name, status) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      target.setStatus(status)

# Extends a move in the move list as an attack with a secondary effect.
#
# name - The name of the move to turn into a secondary effect attack.
# chance - The chance that the secondary effect will activate
# effect - The constructor of the status to inflict
#
# Example:
#
#   extendWithSecondaryEffect 'iron-head', .3, Attachment.Flinch
#
extendWithSecondaryEffect = (name, chance, Klass, options={}) ->
  extendMove name, ->
    oldFunc = @afterSuccessfulHit
    @afterSuccessfulHit = (battle, user, target, damage) ->
      oldFunc.call(this, battle, user, target, damage)
      if battle.rng.next("secondary effect") >= chance
        return

      hash = _.clone(options)
      hash.battle = battle
      target.attach(Klass, hash)

extendWithSecondaryStatus = (name, chance, status) ->
  extendMove name, ->
    oldFunc = @afterSuccessfulHit
    @afterSuccessfulHit = (battle, user, target, damage) ->
      oldFunc.call(this, battle, user, target, damage)
      if battle.rng.next("secondary status") >= chance
        return

      target.setStatus(status)

# The fang moves have an additional 10% chance to flinch.
extendWithFangEffect = (name, chance, status, options) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next("fang status") < chance
        target.setStatus(status)

      if battle.rng.next("fang flinch") < chance
        target.attach(Attachment.Flinch)

extendWithDrain = (name, drainPercent=.5) ->
  extendMove name, ->
    oldFunc = @afterSuccessfulHit
    @afterSuccessfulHit = (battle, user, target, damage) ->
      amount = Math.floor(damage * drainPercent)
      user.drain(amount)
      # TODO: Message after drain
      battle.message "#{user.name} absorbed some HP!"
      oldFunc.call(this, battle, user, target, damage)

extendWithRecoil = (name, recoilPercent=1/3) ->
  extendMove name, ->
    oldFunc = @afterSuccessfulHit
    @afterSuccessfulHit = (battle, user, target, damage) ->
      amount = Math.round(damage * recoilPercent)
      amount = Math.max(1, amount)
      user.damage(amount)
      battle.message("#{user.name} was hit by recoil!")
      oldFunc.call(this, battle, user, target, damage)

makeJumpKick = (name, recoilPercent=.5) ->
  extendMove name, ->
    @afterMiss = (battle, user, target, damage) ->
      amount = Math.floor(damage * recoilPercent)
      user.damage(amount)
      battle.message("#{user.name} kept going and crashed!")

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
      battle.message "#{target.name} recovered #{amount} HP!"
      target.damage(-amount)

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
      amount = if battle.hasWeather(Weather.NONE)
        util.roundHalfDown(target.stat('hp') / 2)
      else if battle.hasWeather(Weather.SUN)
        util.roundHalfDown(target.stat('hp') * 2 / 3)
      else
        util.roundHalfDown(target.stat('hp') / 4)
      battle.message "#{target.name} recovered #{amount} HP!"
      target.damage(-amount)

makeTrickMove = (name) ->
  extendMove name, ->
    @use = ->

    @afterSuccessfulHit = (battle, user, target) ->
      # TODO: Fail message
      return false  unless user.hasItem() && target.hasItem()
      return false  if target.hasAbility('Sticky Hold')
      item = user.getItem()
      user.setItem(battle, target.getItem())
      target.setItem(battle, item)

makeExplosionMove = (name) ->
  extendMove name, ->
    oldExecute = @execute
    @execute = (battle, user, targets) ->
      if !_.any(targets, (target) -> target.hasAbility('Damp'))
        user.faint()
        oldExecute(battle, user, targets)
      else
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

makeProtectMove = (name) ->
  makeProtectCounterMove name, (battle, user, targets) ->
    user.attach(Attachment.Protect)
    battle.message "#{user.name} protected itself!"

makeIdentifyMove = (name, type) ->
  extendMove name, ->
    @use = (battle, user, target) ->
      if target.attach(Attachment.Identify, {type})
        battle.message "#{target.name} was identified!"
      else
        @fail(battle)
        false

makeThiefMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      return  if user.hasItem() || !target.hasItem()
      return  if target.hasAbility('Sticky Hold')
      return  if target.hasAbility('Multitype')
      return  if target.name == "Giratina (origin)"
      return  if target.item.type == 'mail'
      battle.message "#{user.name} stole #{target.name}'s #{target.getItem().name}!"
      user.setItem(battle, target.getItem())
      target.removeItem()

makeStatusCureMove = (name) ->
  extendMove name, ->
    @execute = (battle, user, targets) ->
      for target in targets
        target.removeStatus()

makePickAttackMove = (name) ->
  extendMove name, ->
    @pickAttackStat = (user, target) ->
      target.stat('attack')

makePickDefenseMove = (name) ->
  extendMove name, ->
    @pickDefenseStat = (user, target) ->
      target.stat('defense')

makeRandomSwitchMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      opponent = battle.getOwner(target)
      benched  = opponent.team.getAliveBenchedPokemon()
      return  if benched.length == 0
      pokemon = battle.rng.choice(benched)
      index = opponent.team.indexOf(pokemon)
      opponent.switch(battle, 0, index)

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
      if target.hasAttachment(Attachment.Minimize)
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
      times = user.getAttachment(Attachment.Momentum)?.layers || 0
      bp = @power * Math.pow(2, times)
      bp *= 2  if user.hasAttachment(Attachment.DefenseCurl)
      bp

makeBoostMove = (name, boostTarget, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @use = applyBoosts

makeWeatherMove = (name, weatherType) ->
  extendMove name, ->
    @execute = (battle, user) ->
      length = 5
      length = 8  if weatherType == user.getItem()?.lengthensWeather
      battle.setWeather(weatherType, length)

extendWithBoost = (name, boostTarget, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target) ->
      applyBoosts(battle, user, target)

extendWithSecondaryBoost = (name, boostTarget, chance, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next('secondary boost') >= chance
        return
      applyBoosts(battle, user, target)

boostExtension = (boostTarget, boosts) ->
  (battle, user, target) ->
    boostedStats = if boostTarget == 'self'
      user.boost(boosts)
    else if boostTarget == 'target'
      target.boost(boosts)
    else throw new Error("I don't know what target #{boostTarget} is.")

    pokemon = (if boostTarget == 'self' then user else target)
    util.printBoostMessage(battle, pokemon, boostedStats, boosts)

makeCounterMove = (name, multiplier, applies) ->
  extendMove name, ->
    @getTargets = (battle, user) ->
      # Return the last pokemon who hit this one, if it's alive.
      pokemon = user.lastHitBy?.pokemon
      return [ pokemon ]  if pokemon? && !pokemon.isFainted()
  
      # Return a random target (or none).
      pokemon = battle.getOpponentPokemon(battle.getOwner(user).id)
      pokemon = pokemon.filter((p) -> !p.isFainted())
      if pokemon.length == 0
        []
      else
        [ battle.rng.choice(pokemon) ]

    @calculateDamage = -> 0
  
    @afterSuccessfulHit = (battle, user, target) ->
      hit = user.lastHitBy
      if hit? && applies(hit.move) && hit.turn == battle.turn
        target.damage(multiplier * hit.damage)
      else
        @fail(battle)

makeTrappingMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      unless target.hasAttachment(Attachment.Trap)
        turns = if !user.hasItem("Grip Claw")
          battle.rng.randInt(4, 5, "trapping move")
        else
          7

        target.attach(Attachment.Trap, user: user, moveName: name, turns: turns)
        user.attach(Attachment.TrapLeash, {target})

extendWithDrain 'absorb'
extendWithSecondaryBoost 'acid', 'target', .1, specialDefense: -1
makeBoostMove 'acid-armor', 'self', defense: 2
makeBoostMove 'acid-spray', 'target', specialDefense: -2
makeBoostMove 'agility', 'self', speed: 2
makeBoostMove 'amnesia', 'self', specialDefense: 2
extendWithSecondaryBoost 'ancientpower', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
makeStatusCureMove 'aromatherapy'

extendMove 'attract', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasAttachment(Attachment.Attract) ||
        (!(user.gender == 'M' && target.gender == 'F') &&
         !(user.gender == 'F' && target.gender == 'M'))
      @fail(battle)
      return
    target.attach(Attachment.Attract, source: user)

extendWithSecondaryBoost 'aurora-beam', 'target', .1, attack: -1
makeBoostMove 'autotomize', 'self', speed: 2
makeBoostMove 'barrier', 'self', defense: 2
makeTrappingMove "bind"
makeRechargeMove 'blast-burn'
extendWithSecondaryStatus 'blaze-kick', .1, Status.BURN
extendWithSecondaryStatus 'blizzard', .1, Status.FREEZE
makeMeanLookMove 'block'
extendWithSecondaryStatus 'blue-flare', .2, Status.BURN
extendWithSecondaryStatus 'body-slam', .3, Status.PARALYZE
extendWithSecondaryStatus 'bolt-strike', .2, Status.PARALYZE
extendWithSecondaryEffect 'bone-club', .1, Attachment.Flinch
extendWithSecondaryStatus 'bounce', .3, Status.PARALYZE
extendWithRecoil 'brave-bird'
extendWithSecondaryBoost 'bubble', 'target', .1, speed: -1
extendWithSecondaryBoost 'bubblebeam', 'target', .1, speed: -1
extendWithSecondaryBoost 'bug-buzz', 'target', .1, specialDefense: -1
makeBoostMove 'bulk-up', 'self', attack: 1, defense: 1
extendWithBoost 'bulldoze', 'target', speed: -1
makeBoostMove 'calm-mind', 'self', specialAttack: 1, specialDefense: 1

extendMove 'camouflage', ->
  @use = (battle, user, target) ->
    # Camouflage changes type based on terrain
    # In Wi-Fi battles, the terrain always results in Ground type.
    target.types = [ "Ground" ]

makeBoostMove 'charge', 'self', specialDefense: 1
extendMove 'charge', ->
  oldUse = @use
  @use = (battle, user, target) ->
    user.unattach(Attachment.Charge)  # Charge can be used twice in a row
    user.attach(Attachment.Charge)
    battle.message "#{user.name} began charging power!"
    oldUse.call(this, battle, user, target)

makeBoostMove 'charm', 'target', attack: -2
extendWithSecondaryEffect 'chatter', 1, Attachment.Confusion
extendWithSecondaryBoost 'charge-beam', 'self', .7, specialAttack: 1
makeRandomSwitchMove "circle-throw"
makeTrappingMove "clamp"

extendMove 'clear-smog', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.resetBoosts()
    battle.message "#{target.name}'s stat changes were removed!"

extendWithBoost 'close-combat', 'self', defense: -1, specialDefense: -1
makeBoostMove 'coil', 'self', attack: 1, defense: 1, accuracy: 1
extendWithPrimaryEffect 'confuse-ray', Attachment.Confusion
extendWithSecondaryEffect 'confusion', .1, Attachment.Confusion
extendWithSecondaryBoost 'constrict', 'target', .1, speed: -1

extendMove 'conversion', ->
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

extendMove 'conversion-2', ->
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

makeBoostMove 'cosmic-power', 'self', defense: 1, specialDefense: 1
makeBoostMove 'cotton-guard', 'self', defense: 3
makeBoostMove 'cotton-spore', 'target', speed: -2
makeThiefMove 'covet'
extendWithSecondaryBoost 'crunch', 'target', .2, defense: -1
extendWithSecondaryBoost 'crush-claw', 'target', .5, defense: -1
extendWithSecondaryEffect 'dark-pulse', .2, Attachment.Flinch
extendWithPrimaryStatus 'dark-void', Status.SLEEP
makeBoostMove 'defend-order', 'self', defense: 1, specialDefense: 1
makeBoostMove 'defense-curl', 'self', defense: 1

extendMove 'defense-curl', ->
  oldUse = @use
  @use = (battle, user, target) ->
    oldUse.call(this, battle, user, target)
    target.attach(Attachment.DefenseCurl)

makeProtectMove 'detect'
extendWithSecondaryStatus 'discharge', .3, Status.PARALYZE
extendWithSecondaryEffect 'dizzy-punch', .2, Attachment.Confusion
extendWithRecoil 'double-edge'
makeBoostMove 'double-team', 'self', evasion: 1
makeBoostMove 'dragon-dance', 'self', attack: 1, speed: 1
extendWithSecondaryEffect 'dragon-rush', .2, Attachment.Flinch
extendWithSecondaryStatus 'dragonbreath', .3, Status.PARALYZE
extendWithDrain 'drain-punch'
extendWithDrain 'dream-eater'
extendWithBoost 'draco-meteor', 'self', specialAttack: -2
makeRandomSwitchMove "dragon-tail"
extendWithSecondaryEffect 'dynamicpunch', 1, Attachment.Confusion
extendWithSecondaryBoost 'earth-power', 'target', .1, specialDefense: -1
extendWithBoost 'electroweb', 'target', speed: -1
extendWithSecondaryBoost 'energy-ball', 'target', .1, specialDefense: -1
extendWithSecondaryStatus 'ember', .1, Status.BURN
makeEruptionMove 'eruption'
makeExplosionMove 'explosion'
extendWithSecondaryEffect 'extrasensory', .1, Attachment.Flinch
makeBoostMove 'fake-tears', 'target', specialDefense: -2
extendWithSecondaryEffect 'fake-out', 1, Attachment.Flinch

extendMove 'fake-out', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    if user.turnsActive > 1
      @fail(battle)
      return false

makeBoostMove 'featherdance', 'target', attack: -2

extendMove 'feint', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    target.unattach(Attachment.Protect)

extendWithSecondaryBoost 'fiery-dance', 'self', .5, specialAttack: 1
extendWithSecondaryStatus 'fire-blast', .1, Status.BURN
extendWithFangEffect 'fire-fang', .1, Status.BURN
extendWithSecondaryStatus 'fire-punch', .1, Status.BURN
makeTrappingMove "fire-spin"
makeOneHitKOMove 'fissure'
makeReversalMove 'flail'
extendWithBoost 'flame-charge', 'self', speed: 1
extendMove 'flame-wheel', -> @thawsUser = true
extendWithSecondaryStatus 'flame-wheel', .1, Status.BURN
extendWithSecondaryStatus 'flamethrower', .1, Status.BURN
extendWithRecoil 'flare-blitz'
extendMove 'flare-blitz', -> @thawsUser = true
extendWithSecondaryStatus 'flare-blitz', .1, Status.BURN
extendWithSecondaryBoost 'flash-cannon', 'target', .1, specialDefense: -1
extendWithSecondaryStatus 'force-palm', .3, Status.PARALYZE
extendWithSecondaryBoost 'focus-blast', 'target', .1, specialDefense: -1

extendMove 'focus-energy', ->
  @use = (battle, user, target) ->
    if user.attach(Attachment.FocusEnergy)
      # TODO: Real message
      battle.message "#{user.name} began to focus!"
    else
      @fail(battle)
      false

extendMove 'focus-punch', ->
  @beforeTurn = (battle, user) ->
    user.attach(Attachment.FocusPunch)

makeIdentifyMove("foresight", "Normal")
makePickAttackMove 'foul-play'
extendWithSecondaryStatus 'freeze-shock', .3, Status.PARALYZE
makeRechargeMove 'frenzy-plant'
extendMove 'fusion-flare', -> @thawsUser = true
extendWithDrain 'giga-drain'
makeRechargeMove 'giga-impact'
extendWithBoost 'glaciate', 'target', speed: -1
makeWeightBased 'grass-knot'
extendWithPrimaryStatus 'grasswhistle', Status.SLEEP
makeBoostMove 'growl', 'target', attack: -1
makeBoostMove 'growth', 'self', attack: 1, specialAttack: 1
makeOneHitKOMove 'guillotine'
extendWithSecondaryStatus 'gunk-shot', .3, Status.POISON
extendWithBoost 'hammer-arm', 'self', speed: -1
makeBoostMove 'harden', 'self', defense: 1
extendWithSecondaryEffect 'headbutt', .3, Attachment.Flinch
extendWithRecoil 'head-charge', .25
extendWithRecoil 'head-smash', .5
makeStatusCureMove 'heal-bell'
makeRecoveryMove 'heal-order'
makeRecoveryMove 'heal-pulse'
extendWithSecondaryEffect 'heart-stamp', .3, Attachment.Flinch
makeWeightRatioBased 'heat-crash'
extendWithSecondaryStatus 'heat-wave', .1, Status.BURN
makeWeightRatioBased 'heavy-slam'
makeJumpKick 'hi-jump-kick'
makeBoostMove 'hone-claws', 'self', attack: 1, accuracy: 1
makeOneHitKOMove 'horn-drill'
extendWithDrain 'horn-leech'
makeBoostMove 'howl', 'self', attack: 1
makeRechargeMove 'hydro-cannon'
makeRechargeMove 'hyper-beam'
extendWithPrimaryStatus 'hypnosis', Status.SLEEP
makeMomentumMove 'ice-ball'
extendWithBoost 'icy-wind', 'target', speed: -1
makeBoostMove 'iron-defense', 'self', defense: 2
extendWithSecondaryBoost 'iron-tail', 'target', .1, defense: -1
makeWeatherMove 'hail', Weather.HAIL
extendWithSecondaryEffect 'hurricane', .3, Attachment.Confusion
extendWithSecondaryEffect 'hyper-fang', .1, Attachment.Flinch
extendWithSecondaryStatus 'ice-beam', .1, Status.FREEZE
extendWithSecondaryStatus 'ice-burn', .3, Status.BURN
extendWithFangEffect 'ice-fang', .1, Status.FREEZE
extendWithSecondaryStatus 'ice-punch', .3, Status.FREEZE
extendWithSecondaryEffect 'icicle-crash', .3, Attachment.Flinch
extendWithSecondaryEffect 'iron-head', .3, Attachment.Flinch
makeJumpKick 'jump-kick'
extendWithSecondaryStatus 'lava-plume', .3, Status.BURN
extendWithBoost 'leaf-storm', 'self', specialAttack: -2
extendWithSecondaryBoost 'leaf-tornado', 'target', .3, accuracy: -1
makeBoostMove 'leer', 'target', defense: -1
extendWithDrain 'leech-life'

extendMove 'leech-seed', ->
  oldWillMiss = @willMiss
  @willMiss = (battle, user, target) ->
    if target.hasType("Grass")
      true
    else
      oldWillMiss.call(this, battle, user, target)

  @afterSuccessfulHit = (battle, user, target, damage) ->
    target.attach(Attachment.LeechSeed, {user, target})
    battle.message "#{target.name} was seeded!"

extendWithSecondaryStatus 'lick', .3, Status.PARALYZE
makeLockOnMove 'lock-on'
makeWeightBased 'low-kick'
extendWithBoost 'low-sweep', 'target', speed: -1
extendWithPrimaryStatus 'lovely-kiss', Status.SLEEP
makeTrappingMove "magma-storm"
makeMeanLookMove 'mean-look'
makeBoostMove 'meditate', 'self', attack: 1
extendWithDrain 'mega-drain'
extendWithSecondaryBoost 'metal-claw', 'self', .1, attack: 1
makeBoostMove 'metal-sound', 'target', specialDefense: -2
makeRecoveryMove 'milk-drink'
makeLockOnMove 'mind-reader'

extendMove 'minimize', ->
  applyBoosts = boostExtension('target', evasion: 2)
  @use = (battle, user, target) ->
    applyBoosts(battle, user, target)
    target.attach(Attachment.Minimize)

makeIdentifyMove("miracle-eye", "Psychic")

extendMove 'mirror-move', ->
  @execute = (battle, user, targets) ->
    target = targets[0]
    move = target.lastMove
    if !move? || !move.hasFlag("mirror")
      @fail(battle)
      return false
    move.execute(battle, user, targets)

extendWithSecondaryBoost 'mirror-shot', 'target', .3, accuracy: -1
extendWithSecondaryBoost 'mist-ball', 'target', .5, specialAttack: -1
makeWeatherRecoveryMove 'moonlight'
makeWeatherRecoveryMove 'morning-sun'
extendWithSecondaryBoost 'mud-bomb', 'target', .3, accuracy: -1
extendWithBoost 'mud-shot', 'target', speed: -1
extendWithBoost 'mud-slap', 'target', accuracy: -1
extendWithSecondaryBoost 'muddy-water', 'target', .3, accuracy: -1
makeBoostMove 'nasty-plot', 'self', specialAttack: 2
extendWithSecondaryEffect 'needle-arm', .3, Attachment.Flinch
extendWithSecondaryBoost 'night-daze', 'target', .4, accuracy: -1
makeLevelAsDamageMove 'night-shade'
extendWithSecondaryBoost 'octazooka', 'target', .5, accuracy: -1
makeIdentifyMove("odor-sleuth", "Normal")
extendWithSecondaryBoost 'ominous-wind', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithBoost 'overheat', 'self', specialAttack: -2
extendWithSecondaryStatus 'poison-fang', .3, Status.TOXIC
extendWithPrimaryStatus 'poison-gas', Status.POISON
extendWithSecondaryStatus 'poison-jab', .3, Status.POISON
extendWithPrimaryStatus 'poisonpowder', Status.POISON
extendWithSecondaryStatus 'poison-sting', .3, Status.POISON
extendWithSecondaryStatus 'poison-tail', .1, Status.POISON
extendWithSecondaryStatus 'powder-snow', .1, Status.FREEZE
makeProtectMove 'protect'
extendWithSecondaryEffect 'psybeam', .1, Attachment.Confusion
extendWithSecondaryBoost 'psychic', 'target', .1, specialDefense: -1
extendWithBoost 'psycho-boost', 'self', specialAttack: -2
makePickDefenseMove 'psyshock'
makePickDefenseMove 'psystrike'
makeBasePowerBoostMove 'punishment', 60, 200, 'target'
makeBoostMove 'quiver-dance', 'self', specialAttack: 1, specialDefense: 1, speed: 1
makeWeatherMove 'rain-dance', Weather.RAIN
extendWithSecondaryBoost 'razor-shell', 'target', .5, defense: -1
makeRecoveryMove 'recover'
extendWithSecondaryStatus 'relic-song', .1, Status.SLEEP
makeReversalMove 'reversal'
makeRandomSwitchMove "roar"
makeRechargeMove 'roar-of-time'
extendWithSecondaryEffect 'rock-climb', .2, Attachment.Confusion
makeBoostMove 'rock-polish', 'self', speed: 2
extendWithSecondaryBoost 'rock-smash', 'target', .5, defense: -1
extendWithBoost 'rock-tomb', 'target', speed: -1
extendWithSecondaryEffect 'rock-slide', .3, Attachment.Flinch
makeRechargeMove 'rock-wrecker'
extendWithSecondaryEffect 'rolling-kick', .3, Attachment.Flinch
makeMomentumMove 'rollout'
makeRecoveryMove 'roost'
extendMove 'roost', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    user.attach(Attachment.Roost)

extendWithBoost 'sand-attack', 'target', accuracy: -1
extendMove 'sacred-fire', -> @thawsUser = true
extendWithSecondaryStatus 'sacred-fire', .5, Status.BURN
makeWeatherMove 'sandstorm', Weather.SAND
makeTrappingMove "sand-tomb"
extendMove 'scald', -> @thawsUser = true
extendWithSecondaryStatus 'scald', .3, Status.BURN
makeBoostMove 'scary-face', 'target', speed: -2
makeBoostMove 'screech', 'target', defense: -2
extendWithSecondaryStatus 'searing-shot', .3, Status.BURN
makePickDefenseMove 'secret-sword'
extendWithSecondaryBoost 'seed-flare', 'target', .4, specialDefense: -2
makeExplosionMove 'selfdestruct'
makeLevelAsDamageMove 'seismic-toss'
extendWithSecondaryBoost 'shadow-ball', 'target', .2, specialDefense: -1
makeBoostMove 'sharpen', 'self', attack: 1
makeOneHitKOMove 'sheer-cold'
makeBoostMove 'shell-smash', 'self', {
  attack: 2, specialAttack: 2, speed: 2, defense: -1, specialDefense: -1
}
makeBoostMove 'shift-gear', 'self', speed: 2, attack: 1
extendWithSecondaryEffect 'signal-beam', .1, Attachment.Confusion
extendWithSecondaryBoost 'silver-wind', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithPrimaryStatus 'sing', Status.SLEEP
extendWithSecondaryEffect 'sky-attack', .3, Attachment.Flinch
makeRecoveryMove 'slack-off'
extendWithPrimaryStatus 'sleep-powder', Status.SLEEP
extendWithSecondaryStatus 'sludge', .3, Status.POISON
extendWithSecondaryStatus 'sludge-bomb', .3, Status.POISON
extendWithSecondaryStatus 'sludge-wave', .1, Status.POISON
extendWithSecondaryStatus 'smog', .4, Status.POISON
makeBoostMove 'smokescreen', 'target', accuracy: -1
extendWithBoost 'snarl', 'target', specialAttack: -1
extendWithSecondaryEffect 'snore', .3, Attachment.Flinch
makeRecoveryMove 'softboiled'
extendWithSecondaryStatus 'spark', .3, Status.PARALYZE
makeMeanLookMove 'spider-web'
extendWithPrimaryStatus 'spore', Status.SLEEP
extendWithSecondaryEffect 'steamroller', .3, Attachment.Flinch
makeStompMove 'steamroller'
extendWithSecondaryBoost 'steel-wing', 'self', .1, defense: 1
makeBoostMove 'stockpile', 'self', defense: 1, specialDefense: 1
extendWithSecondaryEffect 'stomp', .3, Attachment.Flinch
makeStompMove 'stomp'
makeBasePowerBoostMove 'stored-power', 20, 860, 'user'
makeBoostMove 'string-shot', 'target', speed: -1
extendWithBoost 'struggle-bug', 'target', specialAttack: -1
extendWithPrimaryStatus 'stun-spore', Status.PARALYZE
extendWithRecoil 'submission', .25
makeWeatherMove 'sunny-day', Weather.SUN
extendWithBoost 'superpower', 'self', attack: -1, defense: -1
extendWithPrimaryEffect 'supersonic', Attachment.Confusion
extendWithPrimaryEffect 'sweet-kiss', Attachment.Confusion
makeBoostMove 'sweet-scent', 'target', evasion: -1
makeTrickMove 'switcheroo'
makeBoostMove 'swords-dance', 'self', attack: 2
extendMove 'super-fang', ->
  @calculateDamage = (battle, user, target) ->
    halfHP = Math.floor(target.currentHP / 2)
    Math.max(1, halfHP)
makeWeatherRecoveryMove 'synthesis'
makeBoostMove 'tail-glow', 'self', attack: 3
makeBoostMove 'tail-whip', 'target', defense: -1
extendWithRecoil 'take-down', .25
extendWithPrimaryEffect 'teeter-dance', Attachment.Confusion
extendMove 'teleport', (battle) ->
  @execute = -> @fail(battle)
makeThiefMove 'thief'
extendWithSecondaryStatus 'thunder', .3, Status.PARALYZE
extendWithFangEffect 'thunder-fang', .1, Status.PARALYZE
extendWithPrimaryStatus 'thunder-wave', Status.PARALYZE
extendWithSecondaryStatus 'thunderbolt', .1, Status.PARALYZE
extendWithSecondaryStatus 'thunderpunch', .1, Status.PARALYZE
extendWithSecondaryStatus 'thundershock', .1, Status.PARALYZE
makeBoostMove 'tickle', 'target', attack: -1, defense: -1
extendWithPrimaryStatus 'toxic', Status.TOXIC
extendMove 'tri-attack', ->
  oldFunc = @afterSuccessfulHit
  @afterSuccessfulHit = (battle, user, target, damage) ->
    oldFunc.call(this, battle, user, target, damage)
    return  if battle.rng.next("secondary status") >= .2
    switch battle.rng.randInt(0, 2, "tri attack effect")
      when 0 then target.setStatus(Status.PARALYZE)
      when 1 then target.setStatus(Status.BURN)
      when 2 then target.setStatus(Status.FREEZE)

makeTrickMove 'trick'
# extendWithSecondaryEffect 'twineedle', .2, Status.POISON
extendWithSecondaryEffect 'twister', .2, Attachment.Flinch
extendWithSecondaryBoost 'v-create', 'self', defense: -1, specialDefense: -1, speed: -1
extendWithSecondaryStatus 'volt-tackle', .1, Status.PARALYZE
extendWithRecoil 'volt-tackle'
extendWithSecondaryEffect 'water-pulse', .2, Attachment.Confusion
makeEruptionMove 'water-spout'
extendWithSecondaryEffect 'waterfall', .2, Attachment.Flinch
makeRandomSwitchMove "whirlwind"
extendWithRecoil 'wild-charge', .25
extendWithPrimaryStatus 'will-o-wisp', Status.BURN
makeBoostMove 'withdraw', 'user', defense: 1
extendWithRecoil 'wood-hammer'
makeBoostMove 'work-up', 'user', attack: 1, specialAttack: 1
makeTrappingMove "wrap"
extendWithSecondaryEffect 'zen-headbutt', .2, Attachment.Flinch
extendWithSecondaryStatus 'zap-cannon', 1, Status.PARALYZE

extendMove 'assurance', ->
  @basePower = (battle, user, target) ->
    hit = user.lastHitBy
    if hit?.turn == battle.turn && !hit.move.isNonDamaging()
      2 * @power
    else
      @power

extendMove 'autotomize', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Autotomize)

extendMove 'acrobatics', ->
  @basePower = (battle, user, target) ->
    if !user.hasItem() then 2 * @power else @power

extendMove 'acupressure', ->
  @use = (battle, user, target) ->
    stats = (stat  for stat, num of target.stages when num < 6)
    if stats.length > 0
      randomStat = battle.rng.choice(stats)
      hash = {}
      hash[randomStat] = 2
      boostExtension('target', hash)(battle, user, target)
    else
      @fail(battle)
      return false

extendMove 'belly-drum', ->
  @use = (battle, user, target) ->
    halfHP = Math.floor(user.stat('hp') / 2)
    if user.currentHP > halfHP
      user.damage(halfHP)
      user.boost(attack: 12)
      battle.message "#{user.name} cut its own HP and maximized its Attack!"
    else
      @fail(battle)
      return false

extendMove 'brick-break', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    {team} = battle.getOwner(target)
    team.unattach(Attachment.Reflect)
    team.unattach(Attachment.LightScreen)

extendMove 'brine', ->
  @basePower = (battle, user, target) ->
    if target.currentHP <= Math.floor(target.stat('hp') / 2)
      2 * @power
    else
      @power

extendMove 'copycat', ->
  @execute = (battle, user, targets) ->
    move = battle.lastMove
    if move? && move != moves['copycat']
      battle.message "#{user.name} used #{move.name}!"
      move.execute(battle, user, targets)
    else
      @fail(battle)


makeCounterMove('counter', 2, (move) -> move.isPhysical())
makeCounterMove('mirror-coat', 2, (move) -> move.isSpecial())
makeCounterMove('metal-burst', 1.5, (move) -> move.isPhysical() || move.isSpecial())

extendMove 'crush-grip', ->
  @basePower = (battle, user, target) ->
    1 + Math.floor(120 * target.currentHP / target.stat('hp'))

extendMove 'curse', ->
  applyBoosts = boostExtension('self', attack: 1, defense: 1, speed: -1)

  @getTargets = (battle, user) ->
    {id} = battle.getOwner(user)
    pokemon = battle.getOpponentPokemon(id)
    [ battle.rng.choice(pokemon, "random opponent") ]

  @execute = (battle, user, targets) ->
    if !user.hasType("Ghost")
      applyBoosts(battle, user)
      return

    user.damage Math.floor(user.stat('hp') / 2)
    for target in targets
      target.attach(Attachment.Curse)
      battle.message "#{user.name} cut its own HP and laid a curse on #{target.name}!"

extendMove 'destiny-bond', ->
  @execute = (battle, user, targets) ->
    user.attach(Attachment.DestinyBond)
    battle.message "#{user.name} is trying to take its foe down with it!"

extendMove 'disable', ->
  # TODO: Disable the last move a pokemon used successfully
  # TODO: Fail if the pokemon has not used a move yet
  # TODO: Fail if the pokemon is already disabled?
  # TODO: Does this stack with cursed body?
  # TODO: Does it disable a move if it's the only one?
  @afterSuccessfulHit = (battle, user, target) ->
    move = target.moves[0]
    turns = battle.rng.randInt(4, 7, "disable")
    target.attach(Attachment.Disable, {move, turns})
    battle.message "#{target.name}'s #{move.name} was disabled!"

extendMove 'dragon-rage', ->
  @calculateDamage = (battle, user, target) ->
    40

extendMove 'dream-eater', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if !target.hasStatus(Status.SLEEP)
      @fail(battle)
      return false
    oldUse.call(this, battle, user, target)

extendMove 'encore', ->
  bannedMoves =
    'encore': true
    'mimic': true
    'mirror-move': true
    'sketch': true
    'struggle': true
    'transform': true
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

extendMove 'endeavor', ->
  oldUse = @use
  @use = (battle, user, target) ->
    return false  if oldUse.call(this, battle, user, target) == false
    if target.currentHP < user.currentHP
      @fail(battle)
      return false

  @calculateDamage = (battle, user, target) ->
    target.currentHP - user.currentHP

extendMove 'endure', ->
  makeProtectCounterMove 'endure', (battle, user, targets) ->
    user.attach(Attachment.Endure)

extendMove 'facade', ->
  @basePower = (battle, user, target) ->
    if user.hasStatus()
      2 * @power
    else
      @power

extendMove 'flatter', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Confusion, {battle})

    boosts = {specialAttack: -2}
    boostedStats = target.boost(boosts)
    util.printBoostMessage(battle, target, boostedStats, boosts)

extendMove 'frustration', ->
  @basePower = -> 102

extendMove 'guard-swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    for stat in [ 'defense', 'specialDefense' ]
      stats = [ target.stages[stat], user.stages[stat] ]
      [ user.stages[stat], target.stages[stat] ] = stats

extendMove 'gyro-ball', ->
  @basePower = (battle, user, target) ->
    power = 1 + Math.floor(25 * target.stat('speed') / user.stat('speed'))
    Math.min(150, power)

extendMove 'haze', ->
  @execute = (battle, user, targets) ->
    user.resetBoosts()
    for target in targets
      target.resetBoosts()
    battle.message "All stat changes were eliminated!"

extendMove 'heart-swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    [user.stages, target.stages] = [target.stages, user.stages]

extendMove 'hex', ->
  @basePower = (battle, user, target) ->
    if target.hasStatus()
      2 * @power
    else
      @power

extendMove 'hidden-power', ->
  hpTypes = [
    'Fighting', 'Flying', 'Poison', 'Ground', 'Rock', 'Bug', 'Ghost',
    'Steel', 'Fire', 'Water', 'Grass', 'Electric', 'Psychic', 'Ice',
    'Dragon', 'Dark'
  ]

  @basePower = (battle, user, target) ->
    base = 0
    base += 1   if user.iv('hp') % 4 > 1
    base += 2   if user.iv('attack') % 4 > 1
    base += 4   if user.iv('defense') % 4 > 1
    base += 8   if user.iv('speed') % 4 > 1
    base += 16  if user.iv('specialAttack') % 4 > 1
    base += 32  if user.iv('specialDefense') % 4 > 1

    Math.floor(base * (40 / 63) + 30)

  @getType = (battle, user, target) ->
    value = 0
    value += 1   if user.iv('hp') % 2 == 1
    value += 2   if user.iv('attack') % 2 == 1
    value += 4   if user.iv('defense') % 2 == 1
    value += 8   if user.iv('speed') % 2 == 1
    value += 16  if user.iv('specialAttack') % 2 == 1
    value += 32  if user.iv('specialDefense') % 2 == 1

    hpTypes[Math.floor(value * 15 / 63)]

extendMove 'incinerate', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    if target.hasItem() && target.getItem().type == 'berries'
      battle.message "#{target.name}'s #{target.getItem().name} was burnt up!"
      target.removeItem()

extendMove 'judgment', ->
  @getType = (battle, user, target) ->
    user.getItem()?.plate || @type

extendMove 'knock-off', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    if target.hasItem()
      battle.message "#{user.name} knocked off #{target.name}'s #{target.getItem().name}!"
      target.removeItem()

extendMove 'light-screen', ->
  @execute = (battle, user, opponents) ->
    {team} = battle.getOwner(user)
    if team.attach(Attachment.LightScreen, {user})
      battle.message "A screen came up!"
    else
      @fail(battle)

extendMove 'magnet-rise', ->
  @use = (battle, user, target) ->
    if target.attach(Attachment.MagnetRise)
      battle.message "#{target.name} is now floating in the air!"
    else
      @fail(battle)
      return false

extendMove 'magnitude', ->
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

extendMove 'me-first', ->
  bannedMoves = {
    "chatter"    : true
    "counter"    : true
    "covet"      : true
    "focus-punch": true
    "me-first"   : true
    "metal-burst": true
    "mirror-coat": true
    "struggle"   : true
    "thief"      : true
  }
  @execute = (battle, user, targets) ->
    target = targets[0]  # Me First is a single-target move
    m = battle.peekMove(target)
    if !battle.willMove(target) || m.isNonDamaging() || bannedMoves[m.name]
      @fail(battle)
      return false
    user.attach(Attachment.MeFirst)
    m.execute(battle, user, targets)

extendMove 'memento', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.currentHP = 0
    boosts = {attack: -2, specialAttack: -2}
    boostedStats = target.boost(boosts)
    util.printBoostMessage(battle, target, boostedStats, boosts)

# TODO: Test
# TODO: Figure out how to redetermine move targets.
extendMove 'metronome', ->
  impossibleMoves =
    "after-you": true
    "assist": true
    "bestow": true
    'chatter': true
    "copycat": true
    "counter": true
    "covet": true
    "destiny-bond": true
    "detect": true
    "endure": true
    "feint": true
    "focus-punch": true
    "follow-me": true
    "freeze-shock": true
    "helping-hand": true
    "ice-burn": true
    "me-first": true
    "mimic": true
    "mirror-coat": true
    "mirror-move": true
    "nature-power": true
    "protect": true
    "quash": true
    "quick-guard": true
    "rage-powder": true
    "relic-song": true
    "secret-sword": true
    "sketch": true
    "sleep-talk": true
    "snatch": true
    "snarl": true
    "snore": true
    "struggle": true
    "switcheroo": true
    "techno-blast": true
    "thief": true
    "transform": true
    "trick": true
    "v-create": true
    "wide-guard": true

  for move of impossibleMoves
    if move not of moves
      throw new Error("The illegal Metronome move '#{move}' does not exist.")

  @execute = (battle, user, targets) ->
    index = battle.rng.randInt(0, moveList.length - 1, "metronome")
    while moveList[index] of impossibleMoves || moveList[index] in user.moves
      index = battle.rng.randInt(0, moveList.length - 1, "metronome")
    move = moveList[index]
    battle.message "Waggling a finger let it use #{move.name}!"
    move.execute(battle, user, targets)

extendMove 'nightmare', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.hasStatus(Status.SLEEP)
      # TODO: What if the Pokemon is already under Nightmare?
      target.attach(Attachment.Nightmare)
    else
      @fail(battle)

extendMove 'pain-split', ->
  @use = (battle, user, target) ->
    averageHP = Math.floor((user.currentHP + target.currentHP) / 2)
    user.setHP(averageHP)
    target.setHP(averageHP)
    battle.message "The battlers shared their pain!"

extendMove 'pay-day', ->
  @afterSuccessfulHit = (battle, user, target) ->
    battle.message "Coins were scattered everywhere!"

extendMove 'payback', ->
  @basePower = (battle, user, target) ->
    if !target.lastMove? || battle.willMove(target)
      @power
    else
      2 * @power

extendMove 'power-swap', ->
  @afterSuccessfulHit = (battle, user, target) ->
    for stat in [ 'attack', 'specialAttack' ]
      stats = [ target.stages[stat], user.stages[stat] ]
      [ user.stages[stat], target.stages[stat] ] = stats

extendMove 'psywave', ->
  @calculateDamage = (battle, user, target) ->
    fraction = battle.rng.randInt(5, 15, "psywave") / 10
    Math.floor(user.level * fraction)

extendMove 'perish-song', ->
  @execute = (battle, user, targets) ->
    battle.message "All Pokemon hearing the song will faint in three turns!"
    # TODO: What if all Pokemon already have Perish Song?
    _.each(targets, (p) -> p.attach(Attachment.PerishSong))

extendMove 'psych-up', ->
  @use = (battle, user, target) ->
    for stage, value of target.stages
      user.stages[stage] = value
    battle.message "#{user.name} copied #{target.name}'s stat changes!"

extendMove 'pursuit', ->
  @beforeTurn = (battle, user) ->
    user.attach(Attachment.Pursuit)

  @basePower = (battle, user, target) ->
    if user.hasAttachment(Attachment.PursuitModifiers)
      2 * @power
    else
      @power

extendMove 'rapid-spin', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    # Do not remove anything if the user is fainted.
    if user.isFainted()
      return

    owner = battle.getOwner(user)
    team = owner.team

    # Remove any entry hazards
    entryHazards = [Attachment.Spikes, Attachment.StealthRock, Attachment.ToxicSpikes]

    hazardRemoved = false
    for hazard in entryHazards
      if team.unattach(hazard)
        hazardRemoved = true

    if hazardRemoved
      battle.message "#{owner.username}'s side of the field is cleared of entry hazards."

    # Remove trapping moves like fire-spin
    trap = user.findAttachment(Attachment.Trap)
    if trap
      battle.message "#{user.name} was freed from #{trap.moveName}!"
      trap.remove()

    # Todo: Remove leech seed once leech seed is implemented

extendMove 'reflect', ->
  @execute = (battle, user, opponents) ->
    {team} = battle.getOwner(user)
    if team.attach(Attachment.Reflect, {user})
      battle.message "A screen came up!"
    else
      @fail(battle)

extendMove 'return', ->
  @basePower = -> 102

extendMove 'spikes', ->
  @execute = (battle, user, opponents) ->
    for opponent in opponents
      if opponent.attachToTeam(Attachment.Spikes)
        battle.message "#{@name} were scattered all around #{opponent.username}'s team's feet!"
      else
        @fail(battle)

extendMove 'spite', ->
  @execute = (battle, user, opponents) ->
    for opponent in opponents
      move = opponent.lastMove
      if !move || !opponent.knows(move) || opponent.pp(move) == 0
        @fail(battle)
        return
      opponent.reducePP(move, 4)
      battle.message "It reduced the PP of #{opponent.name}!"

extendMove 'stealth-rock', ->
  @execute = (battle, user, opponents) ->
    for opponent in opponents
      if opponent.attachToTeam(Attachment.StealthRock)
        battle.message "Pointed stones float in the air around #{opponent.username}'s team!"
      else
        @fail(battle)

extendMove 'splash', ->
  # TODO: Cannot select if Gravity is in effect.
  @execute = (battle, user, target) ->
    battle.message "But nothing happened!"

extendMove 'substitute', ->
  @execute = (battle, user, target) ->
    dmg = user.stat('hp') >> 2
    sub = Attachment.Substitute
    attrs = {hp: dmg, battle: battle}
    if dmg >= user.currentHP || dmg == 0 || !user.attach(sub, attrs)
      battle.message "#{user.name} already has a substitute!"
      @fail(battle)
      return
    user.damage(dmg)
    battle.message "#{user.name} put in a substitute!"

  @fail = (battle) ->

extendMove 'swagger', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(Attachment.Confusion, {battle})
    boosts = {attack: -2}
    boostedStats = target.boost(boosts)
    util.printBoostMessage(battle, target, boostedStats, boosts)

extendMove 'synchronoise', ->
  oldUse = @use
  @use = (battle, user, target) ->
    if _.every(user.types, (type) -> type not in target.types)
      @fail(battle)
      return false
    return oldUse(battle, user, target)

extendMove 'taunt', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.attach(Attachment.Taunt, battle)
      battle.message "#{target.name} fell for the taunt!"
    else
      @fail(battle)

extendMove 'techno-blast', ->
  @getType = (battle, user, target) ->
    switch user.getItem()?.name
      when "Burn Drive"
        "Fire"
      when "Douse Drive"
        "Water"
      when "Shock Drive"
        "Electric"
      else
        "Normal"

extendMove 'torment', ->
  @afterSuccessfulHit = (battle, user, target) ->
    if target.attach(Attachment.Torment)
      battle.message "#{target.name} was subjected to torment!"
    else
      @fail(battle)

extendMove 'toxic-spikes', ->
  @execute = (battle, user, opponents) ->
    for opponent in opponents
      if opponent.attachToTeam(Attachment.ToxicSpikes)
        battle.message "Poison spikes were scattered all around #{opponent.username}'s team's feet!"
      else
        @fail(battle)

extendMove 'trump-card', ->
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

extendMove 'u-turn', ->
  @afterSuccessfulHit = (battle, user, target) ->
    battle.forceSwitch(user)

extendMove 'venoshock', ->
  @basePower = (battle, user, target) ->
    if target.hasStatus(Status.TOXIC, Status.POISON)
      2 * @power
    else
      @power

extendMove 'volt-switch', ->
  @afterSuccessfulHit = (battle, user, target) ->
    battle.forceSwitch(user)

extendMove 'weather-ball', ->
  @getType = (battle, user, target) ->
    if      battle.hasWeather(Weather.SUN)  then 'Fire'
    else if battle.hasWeather(Weather.RAIN) then 'Water'
    else if battle.hasWeather(Weather.HAIL) then 'Ice'
    else if battle.hasWeather(Weather.SAND) then 'Rock'
    else 'Normal'

  @basePower = (battle, user, target) ->
    if battle.hasWeather(Weather.NONE) then 50 else 100


extendMove 'wish', ->
  @execute = (battle, user, targets) ->
    team = battle.getOwner(user).team
    @fail(battle)  unless team.attach(Attachment.Wish, {user})

extendMove 'wring-out', ->
  @basePower = (battle, user, target) ->
    power = Math.floor(120 * user.currentHP / user.stat('hp'))
    Math.max(1, power)

extendMove 'yawn', ->
  # TODO: Fail if the opponent already has a status
  # TODO: Fail if safeguard is activate
  # NOTE: Insomnia and Vital Spirit guard against the sleep effect
  # but not yawn itself.
  @afterSuccessfulHit = (battle, user, target) ->
    if target.attach(Attachment.Yawn)
      # TODO: Real message
      battle.message "#{target.name} began yawning!"
    else
      @fail(battle)

# Keep this at the bottom or look up how it affects Metronome.
# TODO: Figure out a better solution
moves['confusion-recoil'] = new Move "Confusion recoil",
  "accuracy": 0,
  "damage": "physical",
  "power": 40,
  "priority": 0,
  "type": "???"

# Confusion never crits
extendMove 'confusion-recoil', ->
  @isCriticalHit = -> false

moves['recharge'] = new Move("Recharge", target: "user")
