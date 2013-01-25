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
for name, attributes of @MoveData
  @moves[name] = new Move(name, attributes)


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
extendWithSecondaryEffect = (name, chance, Klass, options) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next("secondary effect") >= chance
        return

      # TODO: Maybe find a better way to do this.
      if Klass == Attachment.Confusion
        options.turns ||= battle.rng.nextInt(1, 4)

      target.attach(new Klass(options))

extendWithSecondaryStatus = (name, chance, status) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
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
        target.attach(new Attachment.Flinch(options))

extendWithDrain = (name, drainPercent=.5) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      amount = Math.floor(damage * drainPercent)
      user.damage(-amount)
      # TODO: Message after drain

extendWithRecoil = (name, recoilPercent=1/3) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      amount = Math.floor(damage * recoilPercent)
      user.damage(amount)
      battle.message("#{user.name} was hit by recoil!")

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
      amount = Math.round(target.stat('hp') / 2)
      battle.message "#{target.name} recovered #{amount} HP!"
      target.damage(-amount)

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
    @use = (battle, user, target) ->
      # TODO: Fail message
      return false  unless user.item? && target.item?
      return false  if target.hasAbility('Sticky Hold')
      [user.item, target.item] = [target.item, user.item]

makeExplosionMove = (name) ->
  extendMove name, ->
    oldExecute = @execute
    @execute = (battle, user, targets) ->
      if !_.any(targets, (target) -> target.hasAbility('Damp'))
        # TODO: Real faint?
        user.currentHP = 0
        oldExecute(battle, user, targets)
      else
        battle.message "#{user.name} cannot use #{@name}!"

makeThiefMove = (name) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      return  if user.item?
      return  if target.hasAbility('Sticky Hold')
      return  if target.hasAbility('Multitype')
      battle.message "#{user.name} stole #{target.name}'s #{target.item.name}!"
      [user.item, target.item] = [target.item, null]

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

makeBoostMove = (name, boostTarget, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @use = applyBoosts

extendWithBoost = (name, boostTarget, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    oldUse = @use
    @use = (battle, user, target, damage) ->
      if oldUse(battle, user, target, damage) != false
        applyBoosts(battle, user, target, damage)

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

    for stat, wasBoosted of boostedStats
      pokemon = (if boostTarget == 'self' then user else target)
      message = makeBoostMessage(pokemon, stat, boosts[stat], wasBoosted)
      battle.message(message)  if message?

makeBoostMessage = (pokemon, stat, amount, wasBoosted) ->
  if wasBoosted && amount > 0
    adverb = ""              if amount == 1
    adverb = " sharply"      if amount == 2
    adverb = " drastically"  if amount >= 3
    "#{pokemon.name}'s #{stat} rose#{adverb}!"
  else if wasBoosted && amount < 0
    adverb = ""           if amount == -1
    adverb = " harshly"   if amount == -2
    adverb = " severely"  if amount <= -3
    "#{pokemon.name}'s #{stat}#{adverb} fell!"
  else if !wasBoosted && amount > 0
    "#{pokemon.name}'s #{stat} won't go any higher!"
  else if !wasBoosted && amount < 0
    "#{pokemon.name}'s #{stat} won't go any lower!"

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
extendWithSecondaryBoost 'aurora-beam', 'target', .1, attack: -1
makeBoostMove 'autotomize', 'self', speed: 2
makeBoostMove 'barrier', 'self', defense: 2
extendWithSecondaryStatus 'blaze-kick', .1, Status.BURN
extendWithSecondaryStatus 'blizzard', .1, Status.FREEZE
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
makeBoostMove 'charm', 'target', attack: -2
extendWithSecondaryBoost 'charge-beam', 'self', .7, specialAttack: 1
extendWithBoost 'close-combat', 'self', defense: -1, specialDefense: -1
makeBoostMove 'coil', 'self', attack: 1, defense: 1, accuracy: 1
extendWithSecondaryEffect 'confusion', .1, Attachment.Confusion
extendWithSecondaryBoost 'constrict', 'target', .1, speed: -1
makeBoostMove 'cosmic-power', 'self', defense: 1, specialDefense: 1
makeBoostMove 'cotton-guard', 'self', defense: 3
makeBoostMove 'cotton-spore', 'target', speed: -2
makeThiefMove 'covet'
extendWithSecondaryBoost 'crunch', 'target', .2, defense: -1
extendWithSecondaryBoost 'crush-claw', 'target', .5, defense: -1
extendWithSecondaryEffect 'dark-pulse', .2, Attachment.Flinch
makeBoostMove 'defend-order', 'self', defense: 1, specialDefense: 1
makeBoostMove 'defense-curl', 'self', defense: 1
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
extendWithSecondaryBoost 'earth-power', 'target', .1, specialDefense: -1
extendWithBoost 'electroweb', 'target', speed: -1
extendWithSecondaryBoost 'energy-ball', 'target', .1, specialDefense: -1
extendWithSecondaryStatus 'ember', .1, Status.BURN
makeEruptionMove 'eruption'
makeExplosionMove 'explosion'
extendWithSecondaryEffect 'extrasensory', .1, Attachment.Flinch
makeBoostMove 'fake-tears', 'target', specialDefense: -2
makeBoostMove 'featherdance', 'target', attack: -2
extendWithSecondaryEffect 'fake-out', 1, Attachment.Flinch
extendWithSecondaryBoost 'fiery-dance', 'self', .5, specialAttack: 1
extendWithSecondaryStatus 'fire-blast', .1, Status.BURN
extendWithFangEffect 'fire-fang', .1, Status.BURN
extendWithSecondaryStatus 'fire-punch', .1, Status.BURN
makeOneHitKOMove 'fissure'
makeReversalMove 'flail'
extendWithBoost 'flame-charge', 'self', speed: 1
extendMove 'flame-wheel', -> @thawsUser = true
extendWithSecondaryStatus 'flame-wheel', .1, Status.BURN
extendWithSecondaryStatus 'flamethrower', .1, Status.BURN
# TODO: Add recoil to flare-blitz.
extendMove 'flare-blitz', -> @thawsUser = true
extendWithSecondaryStatus 'flare-blitz', .1, Status.BURN
extendWithSecondaryBoost 'flash-cannon', 'target', .1, specialDefense: -1
extendWithSecondaryStatus 'force-palm', .3, Status.PARALYZE
extendWithSecondaryBoost 'focus-blast', 'target', .1, specialDefense: -1
makePickAttackMove 'foul-play'
extendWithSecondaryStatus 'freeze-shock', .3, Status.PARALYZE
extendMove 'fusion-flare', -> @thawsUser = true
extendWithDrain 'giga-drain'
extendWithBoost 'glaciate', 'target', speed: -1
makeWeightBased 'grass-knot'
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
extendWithBoost 'icy-wind', 'target', speed: -1
makeBoostMove 'iron-defense', 'self', defense: 2
extendWithSecondaryBoost 'iron-tail', 'target', .1, defense: -1
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
extendWithSecondaryStatus 'lick', .3, Status.PARALYZE
makeWeightBased 'low-kick'
extendWithBoost 'low-sweep', 'target', speed: -1
makeBoostMove 'meditate', 'self', attack: 1
extendWithDrain 'mega-drain'
extendWithSecondaryBoost 'metal-claw', 'self', .1, attack: 1
makeBoostMove 'metal-sound', 'target', specialDefense: -2
makeRecoveryMove 'milk-drink'
makeBoostMove 'minimize', 'self', evasion: 2
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
extendWithSecondaryBoost 'ominous-wind', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithBoost 'overheat', 'self', specialAttack: -2
extendWithSecondaryStatus 'poison-fang', .3, Status.TOXIC
extendWithSecondaryStatus 'poison-jab', .3, Status.POISON
extendWithSecondaryStatus 'poison-sting', .3, Status.POISON
extendWithSecondaryStatus 'poison-tail', .1, Status.POISON
extendWithSecondaryStatus 'powder-snow', .1, Status.FREEZE
extendWithSecondaryEffect 'psybeam', .1, Attachment.Confusion
extendWithSecondaryBoost 'psychic', 'target', .1, specialDefense: -1
extendWithBoost 'psycho-boost', 'self', specialAttack: -2
makePickDefenseMove 'psyshock'
makePickDefenseMove 'psystrike'
makeBoostMove 'quiver-dance', 'self', specialAttack: 1, specialDefense: 1, speed: 1
extendWithSecondaryBoost 'razor-shell', 'target', .5, defense: -1
makeRecoveryMove 'recover'
extendWithSecondaryStatus 'relic-song', .1, Status.SLEEP
makeReversalMove 'reversal'
extendWithSecondaryEffect 'rock-climb', .2, Attachment.Confusion
makeBoostMove 'rock-polish', 'self', speed: 2
extendWithSecondaryBoost 'rock-smash', 'target', .5, defense: -1
extendWithBoost 'rock-tomb', 'target', speed: -1
extendWithSecondaryEffect 'rock-slide', .3, Attachment.Flinch
extendWithSecondaryEffect 'rolling-kick', .3, Attachment.Flinch
# TODO: Temporarily remove Flying type
makeRecoveryMove 'roost'
extendWithBoost 'sand-attack', 'target', accuracy: -1
extendMove 'sacred-fire', -> @thawsUser = true
extendWithSecondaryStatus 'sacred-fire', .5, Status.BURN
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
extendWithSecondaryEffect 'sky-attack', .3, Attachment.Flinch
makeRecoveryMove 'slack-off'
extendWithSecondaryStatus 'sludge', .3, Status.POISON
extendWithSecondaryStatus 'sludge-bomb', .3, Status.POISON
extendWithSecondaryStatus 'sludge-wave', .1, Status.POISON
extendWithSecondaryStatus 'smog', .4, Status.POISON
makeBoostMove 'smokescreen', 'target', accuracy: -1
extendWithBoost 'snarl', 'target', specialAttack: -1
extendWithSecondaryEffect 'snore', .3, Attachment.Flinch
makeRecoveryMove 'softboiled'
extendWithSecondaryStatus 'spark', .3, Status.PARALYZE
extendWithSecondaryEffect 'steamroller', .3, Attachment.Flinch
extendWithSecondaryBoost 'steel-wing', 'self', .1, defense: 1
makeBoostMove 'stockpile', 'self', defense: 1, specialDefense: 1
extendWithSecondaryEffect 'stomp', .3, Attachment.Flinch
makeBoostMove 'string-shot', 'target', speed: -1
extendWithBoost 'struggle-bug', 'target', specialAttack: -1
extendWithRecoil 'submission', .25
extendWithBoost 'superpower', 'self', attack: -1, defense: -1
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
extendMove 'teleport', (battle) ->
  @execute = -> @fail(battle)
makeThiefMove 'thief'
extendWithSecondaryStatus 'thunder', .3, Status.PARALYZE
extendWithFangEffect 'thunder-fang', .1, Status.PARALYZE
extendWithSecondaryStatus 'thunderbolt', .1, Status.PARALYZE
extendWithSecondaryStatus 'thunderpunch', .1, Status.PARALYZE
extendWithSecondaryStatus 'thundershock', .1, Status.PARALYZE
makeBoostMove 'tickle', 'target', attack: -1, defense: -1
# extendWithSecondaryEffect 'tri-attack', .1, Status.PARALYZE
makeTrickMove 'trick'
# extendWithSecondaryEffect 'twineedle', .2, Status.POISON
extendWithSecondaryEffect 'twister', .2, Attachment.Flinch
extendWithSecondaryBoost 'v-create', 'self', defense: -1, specialDefense: -1, speed: -1
# TODO: Volt tackle should have 1/3 recoil.
extendWithSecondaryStatus 'volt-tackle', .1, Status.PARALYZE
extendWithSecondaryEffect 'water-pulse', .2, Attachment.Confusion
makeEruptionMove 'water-spout'
extendWithSecondaryEffect 'waterfall', .2, Attachment.Flinch
extendWithRecoil 'wild-charge', .25
makeBoostMove 'withdraw', 'user', defense: 1
extendWithRecoil 'wood-hammer'
makeBoostMove 'work-up', 'user', attack: 1, specialAttack: 1
extendWithSecondaryEffect 'zen-headbutt', .2, Attachment.Flinch

extendMove 'autotomize', ->
  @afterSuccessfulHit = (battle, user, target) ->
    target.attach(new Attachment.Autotomize())

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
  @use = (battle, user, target, damage) ->
    halfHP = Math.floor(user.stat('hp') / 2)
    if user.currentHP > halfHP
      user.damage(halfHP)
      user.boost(attack: 12)
      battle.message "#{user.name} cut its own HP and maximized its Attack!"
    else
      @fail(battle)
      return false

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

extendMove 'crush-grip', ->
  @basePower = (battle, user, target) ->
    1 + Math.floor(120 * target.currentHP / target.stat('hp'))

extendMove 'disable', ->
  # TODO: Disable the last move a pokemon used successfully
  # TODO: Fail if the pokemon has not used a move yet
  # TODO: Fail if the pokemon is already disabled?
  # TODO: Does this stack with cursed body?
  # TODO: Does it disable a move if it's the only one?
  @use = (battle, user, target) ->
    move = target.moves[0]
    turns = battle.rng.randInt(4, 7, "disable")
    target.attach(new Attachment.Disabled(move: move, turns: turns))
    battle.message "#{target.name}'s #{move.name} was disabled!"

extendMove 'dragon-rage', ->
  @calculateDamage = (battle, user, target) ->
    40

extendMove 'endeavor', ->
  @use = (battle, user, target, damage) ->
    if target.isImmune(this, battle, user)
      battle.message "But it doesn't affect #{target.name}..."
      return false

    if target.currentHP >= user.currentHP
      target.currentHP = user.currentHP
    else
      @fail(battle)
      return false

extendMove 'facade', ->
  @basePower = (battle, user, target) ->
    if user.hasStatus()
      2 * @power
    else
      @power

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
  @use = (battle, user, target, damage) ->
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
    if target.item.type == 'berries'
      battle.message "#{target.name}'s #{target.item.name} was burnt up!"
      delete target.item

extendMove 'judgment', ->
  @getType = (battle, user, target) ->
    user.item?.plate || @type

extendMove 'knock-off', ->
  @afterSuccessfulHit = (battle, user, target, damage) ->
    if target.item?
      battle.message "#{user.name} knocked off #{target.name}'s #{target.item.name}!"
      target.item = null

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

extendMove 'memento', ->
  @use = (battle, user, target, damage) ->
    user.currentHP = 0
    target.boost(attack: -2, specialAttack: -2)

extendMove 'nightmare', ->
  @use = (battle, user, target, damage) ->
    if target.hasStatus(Status.SLEEP)
      target.attach(new Attachment.Nightmare)
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

extendMove 'psywave', ->
  @calculateDamage = (battle, user, target) ->
    fraction = battle.rng.randInt(5, 15, "psywave") / 10
    Math.floor(user.level * fraction)

extendMove 'splash', ->
  # TODO: Cannot select if Gravity is in effect.
  @execute = (battle, user, target) ->
    battle.message "But nothing happened!"

extendMove 'weather-ball', ->
  @getType = (battle, user, target) ->
    if      battle.hasWeather(Weather.SUN)  then 'Fire'
    else if battle.hasWeather(Weather.RAIN) then 'Water'
    else if battle.hasWeather(Weather.HAIL) then 'Ice'
    else if battle.hasWeather(Weather.SAND) then 'Rock'
    else 'Normal'

  @basePower = (battle, user, target) ->
    if battle.hasWeather(Weather.NONE) then 50 else 100

extendMove 'yawn', ->
  # TODO: Fail if the opponent already has a status
  # TODO: Fail if safeguard is activate
  # TODO: Fail if the pokemon is already tired
  # NOTE: Insomnia and Vital Spirit guard against the sleep effect
  # but not yawn itself.
  @use = (battle, user, target) ->
    target.attach(new Attachment.Yawn())

moves['confusion-recoil'] = new Move "Confusion recoil",
  "accuracy": 0,
  "damage": "physical",
  "power": 40,
  "priority": 0,
  "type": "Normal"

extendMove 'confusion-recoil', ->
  @typeEffectiveness = ->
    1
