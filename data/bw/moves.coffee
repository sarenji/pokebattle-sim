# Create the move objects of every single move in the game

@MoveData = require('./data_moves.json')
{Move} = require('../../server/move')
{BurnAttachment, FreezeAttachment, ParalyzeAttachment, FlinchAttachment,
PoisonAttachment, ToxicAttachment, SleepAttachment,
ConfusionAttachment} = require('../../server/attachment')

# Generate the initial versions of every single move.
# Some of these will be overwritten later.
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

  # todo: Use an adapter so that it works like in the example
  callback.call(move, move.attributes)

extendMove 'splash', ->
  # TODO: Cannot select if Gravity is in effect.
  @execute = (battle, user, target) ->
    battle.message "But nothing happened!"


# Extends a move in the move list as an attack with a secondary effect.
# The chance of the effect is determined by the value of the
# effectChance attribute.
#
# name - The name of the move to turn into a secondary effect attack.
# chance - The chance that the secondary effect will activate
# effect - The constructor of the status to inflict
#
# Example:
#
#   extendWithSecondaryEffect 'flamethrower', .1, BurnAttachment
#
extendWithSecondaryEffect = (name, chance, Attachment, options) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next() >= chance
        return

      attachment = new Attachment(options)
      target.attach(attachment)

# The fang moves have an additional 10% chance to flinch.
extendWithFangEffect = (name, chance, Attachment, options) ->
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next() < chance
        attachment = new Attachment(options)
        target.attach(attachment)

      if battle.rng.next() < chance
        attachment = new FlinchAttachment(options)
        target.attach(attachment)

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
      if target.weight <= 100       then 20
      else if target.weight <= 250  then 40
      else if target.weight <= 500  then 60
      else if target.weight <= 1000 then 80
      else if target.weight <= 2000 then 100
      else                               120

makeLevelAsDamageMove = (name) ->
  extendMove name, ->
    @calculateDamage = (battle, user, target) ->
      user.level

extendWithBoost = (name, boostTarget, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @afterSuccessfulHit = applyBoosts

extendWithSecondaryBoost = (name, boostTarget, chance, boosts) ->
  applyBoosts = boostExtension(boostTarget, boosts)
  extendMove name, ->
    @afterSuccessfulHit = (battle, user, target, damage) ->
      if battle.rng.next() >= chance
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
extendWithBoost 'acid-armor', 'self', defense: 2
extendWithBoost 'acid-spray', 'target', specialDefense: -2
extendWithBoost 'agility', 'self', speed: 2
extendWithBoost 'amnesia', 'self', specialDefense: 2
extendWithSecondaryBoost 'ancientpower', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithSecondaryBoost 'aurora-beam', 'target', .1, attack: -1
extendWithBoost 'autotomize', 'self', speed: 2
extendWithBoost 'barrier', 'self', defense: 2
extendWithSecondaryEffect 'blaze-kick', .1, BurnAttachment
extendWithSecondaryEffect 'blizzard', .1, FreezeAttachment
extendWithSecondaryEffect 'blue-flare', .2, BurnAttachment
extendWithSecondaryEffect 'body-slam', .3, ParalyzeAttachment
extendWithSecondaryEffect 'bolt-strike', .2, ParalyzeAttachment
extendWithSecondaryEffect 'bone-club', .1, FlinchAttachment
extendWithSecondaryEffect 'bounce', .3, ParalyzeAttachment
extendWithRecoil 'brave-bird'
extendWithSecondaryBoost 'bubble', 'target', .1, speed: -1
extendWithSecondaryBoost 'bubblebeam', 'target', .1, speed: -1
extendWithSecondaryBoost 'bug-buzz', 'target', .1, specialDefense: -1
extendWithBoost 'bulk-up', 'self', attack: 1, defense: 1
extendWithBoost 'bulldoze', 'target', speed: -1
extendWithBoost 'calm-mind', 'self', specialAttack: 1, specialDefense: 1
extendWithBoost 'charm', 'target', attack: -2
extendWithSecondaryBoost 'charge-beam', 'self', .7, specialAttack: 1
extendWithBoost 'close-combat', 'self', defense: -1, specialDefense: -1
extendWithBoost 'coil', 'self', attack: 1, defense: 1, accuracy: 1
extendWithSecondaryEffect 'confusion', .1, ConfusionAttachment
extendWithSecondaryBoost 'constrict', 'target', .1, speed: -1
extendWithBoost 'cosmic-power', 'self', defense: 1, specialDefense: 1
extendWithBoost 'cotton-guard', 'self', defense: 3
extendWithBoost 'cotton-spore', 'target', speed: -2
extendWithSecondaryBoost 'crunch', 'target', .2, defense: -1
extendWithSecondaryBoost 'crush-claw', 'target', .5, defense: -1
extendWithSecondaryEffect 'dark-pulse', .2, FlinchAttachment
extendWithBoost 'defend-order', 'self', defense: 1, specialDefense: 1
extendWithBoost 'defense-curl', 'self', defense: 1
extendWithSecondaryEffect 'discharge', .3, ParalyzeAttachment
extendWithSecondaryEffect 'dizzy-punch', .2, ConfusionAttachment
extendWithRecoil 'double-edge'
extendWithBoost 'double-team', 'self', evasion: 1
extendWithBoost 'dragon-dance', 'self', attack: 1, speed: 1
extendWithSecondaryEffect 'dragon-rush', .2, FlinchAttachment
extendWithSecondaryEffect 'dragonbreath', .3, ParalyzeAttachment
extendWithDrain 'drain-punch'
extendWithDrain 'dream-eater'
extendWithBoost 'draco-meteor', 'self', specialAttack: -2
extendWithSecondaryBoost 'earth-power', 'target', .1, specialDefense: -1
extendWithBoost 'electroweb', 'target', speed: -1
extendWithSecondaryBoost 'energy-ball', 'target', .1, specialDefense: -1
extendWithSecondaryEffect 'ember', .1, BurnAttachment
extendWithSecondaryEffect 'extrasensory', .1, FlinchAttachment
extendWithBoost 'fake-tears', 'target', specialDefense: -2
extendWithBoost 'featherdance', 'target', attack: -2
extendWithBoost 'fiery-dance', 'self', specialAttack: 1
extendWithSecondaryEffect 'fire-blast', .1, BurnAttachment
extendWithFangEffect 'fire-fang', .1, BurnAttachment
extendWithSecondaryEffect 'fire-punch', .1, BurnAttachment
extendWithBoost 'flame-charge', 'self', speed: 1
extendWithSecondaryEffect 'flame-wheel', .1, BurnAttachment
extendWithSecondaryEffect 'flamethrower', .1, BurnAttachment
# TODO: Add recoil to flare-blitz.
extendWithSecondaryEffect 'flare-blitz', .1, BurnAttachment
extendWithSecondaryBoost 'flash-cannon', 'target', .1, specialDefense: -1
extendWithSecondaryEffect 'force-palm', .3, ParalyzeAttachment
extendWithSecondaryBoost 'focus-blast', 'target', .1, specialDefense: -1
extendWithSecondaryEffect 'freeze-shock', .3, ParalyzeAttachment
extendWithDrain 'giga-drain'
extendWithBoost 'glaciate', 'target', speed: -1
makeWeightBased 'grass-knot'
extendWithBoost 'growl', 'target', attack: -1
extendWithBoost 'growth', 'self', attack: 1, specialAttack: 1
extendWithSecondaryEffect 'gunk-shot', .3, PoisonAttachment
extendWithBoost 'hammer-arm', 'self', speed: -1
extendWithBoost 'harden', 'self', defense: 1
extendWithBoost 'harden', 'self', defense: 1
extendWithSecondaryEffect 'headbutt', .3, FlinchAttachment
extendWithRecoil 'head-charge', .25
extendWithRecoil 'head-smash', .5
extendWithSecondaryEffect 'heart-stamp', .3, FlinchAttachment
extendWithSecondaryEffect 'heat-wave', .1, BurnAttachment
makeJumpKick 'hi-jump-kick'
extendWithBoost 'hone-claws', 'self', attack: 1, accuracy: 1
extendWithDrain 'horn-leech'
extendWithBoost 'howl', 'self', attack: 1
extendWithBoost 'icy-wind', 'target', speed: -1
extendWithBoost 'iron-defense', 'self', defense: 2
extendWithSecondaryBoost 'iron-tail', 'target', .1, defense: -1
extendWithSecondaryEffect 'hurricane', .3, ConfusionAttachment
extendWithSecondaryEffect 'hyper-fang', .1, FlinchAttachment
extendWithSecondaryEffect 'ice-beam', .1, FreezeAttachment
extendWithSecondaryEffect 'ice-burn', .3, BurnAttachment
extendWithFangEffect 'ice-fang', .1, FreezeAttachment
extendWithSecondaryEffect 'ice-punch', .3, FreezeAttachment
extendWithSecondaryEffect 'icicle-crash', .3, FlinchAttachment
extendWithSecondaryEffect 'iron-head', .3, FlinchAttachment
makeJumpKick 'jump-kick'
extendWithSecondaryEffect 'lava-plume', .3, BurnAttachment
extendWithBoost 'leaf-storm', 'self', specialAttack: -2
extendWithSecondaryBoost 'leaf-tornado', 'target', .3, accuracy: -1
extendWithBoost 'leer', 'target', defense: -1
extendWithDrain 'leech-life'
extendWithSecondaryEffect 'lick', .3, ParalyzeAttachment
makeWeightBased 'low-kick'
extendWithBoost 'low-sweep', 'target', speed: -1
extendWithBoost 'meditate', 'self', attack: 1
extendWithDrain 'mega-drain'
extendWithSecondaryBoost 'metal-claw', 'self', .1, attack: 1
extendWithBoost 'metal-sound', 'target', specialDefense: -2
extendWithBoost 'minimize', 'self', evasion: 2
extendWithSecondaryBoost 'mirror-shot', 'target', .3, accuracy: -1
extendWithSecondaryBoost 'mist-ball', 'target', .5, specialAttack: -1
extendWithSecondaryBoost 'mud-bomb', 'target', .3, accuracy: -1
extendWithBoost 'mud-shot', 'target', speed: -1
extendWithBoost 'mud-slap', 'target', accuracy: -1
extendWithSecondaryBoost 'muddy-water', 'target', .3, accuracy: -1
extendWithBoost 'nasty-plot', 'self', specialAttack: 2
extendWithSecondaryEffect 'needle-arm', .3, FlinchAttachment
extendWithSecondaryBoost 'night-daze', 'target', .4, accuracy: -1
makeLevelAsDamageMove 'night-shade'
extendWithSecondaryBoost 'octazooka', 'target', .5, accuracy: -1
extendWithSecondaryBoost 'ominous-wind', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithBoost 'overheat', 'self', specialAttack: -2
extendWithSecondaryEffect 'poison-fang', .3, ToxicAttachment
extendWithSecondaryEffect 'poison-jab', .3, PoisonAttachment
extendWithSecondaryEffect 'poison-sting', .3, PoisonAttachment
extendWithSecondaryEffect 'poison-tail', .1, PoisonAttachment
extendWithSecondaryEffect 'powder-snow', .1, FreezeAttachment
extendWithSecondaryEffect 'psybeam', .1, ConfusionAttachment
extendWithSecondaryBoost 'psychic', 'target', .1, specialDefense: -1
extendWithBoost 'psycho-boost', 'self', specialAttack: -2
extendWithBoost 'quiver-dance', 'self', specialAttack: 1, specialDefense: 1, speed: 1
extendWithSecondaryBoost 'razor-shell', 'target', .5, defense: -1
extendWithSecondaryEffect 'relic-song', .1, SleepAttachment
extendWithSecondaryEffect 'rock-climb', .2, ConfusionAttachment
extendWithBoost 'rock-polish', 'self', speed: 2
extendWithSecondaryBoost 'rock-smash', 'target', .5, defense: -1
extendWithBoost 'rock-tomb', 'target', speed: -1
extendWithSecondaryEffect 'rock-slide', .3, FlinchAttachment
extendWithSecondaryEffect 'rolling-kick', .3, FlinchAttachment
extendWithBoost 'sand-attack', 'target', accuracy: -1
extendWithSecondaryEffect 'scald', .3, BurnAttachment
extendWithBoost 'scary-face', 'target', speed: -2
extendWithBoost 'screech', 'target', defense: -2
extendWithSecondaryEffect 'searing-shot', .3, BurnAttachment
extendWithSecondaryBoost 'seed-flare', 'target', .4, specialDefense: -2
makeLevelAsDamageMove 'seismic-toss'
extendWithSecondaryBoost 'shadow-ball', 'target', .2, specialDefense: -1
extendWithBoost 'sharpen', 'self', attack: 1
extendWithBoost 'shell-smash', 'self', {
  attack: 2, specialAttack: 2, speed: 2, defense: -1, specialDefense: -1
}
extendWithBoost 'shift-gear', 'self', speed: 2, attack: 1
extendWithSecondaryEffect 'signal-beam', .1, ConfusionAttachment
extendWithSecondaryBoost 'silver-wind', 'self', .1, {
  attack: 1, defense: 1, speed: 1, specialAttack: 1, specialDefense: 1
}
extendWithSecondaryEffect 'sky-attack', .3, FlinchAttachment
extendWithSecondaryEffect 'sludge', .3, PoisonAttachment
extendWithSecondaryEffect 'sludge-bomb', .3, PoisonAttachment
extendWithSecondaryEffect 'sludge-wave', .1, PoisonAttachment
extendWithSecondaryEffect 'smog', .4, PoisonAttachment
extendWithBoost 'smokescreen', 'target', accuracy: -1
extendWithBoost 'snarl', 'target', specialAttack: -1
extendWithSecondaryEffect 'snore', .3, FlinchAttachment
extendWithSecondaryEffect 'spark', .3, ParalyzeAttachment
extendWithSecondaryEffect 'steamroller', .3, FlinchAttachment
extendWithSecondaryBoost 'steel-wing', 'self', .1, defense: 1
extendWithBoost 'stockpile', 'self', defense: 1, specialDefense: 1
extendWithSecondaryEffect 'stomp', .3, FlinchAttachment
extendWithBoost 'string-shot', 'target', speed: -1
extendWithBoost 'struggle-bug', 'target', specialAttack: -1
extendWithRecoil 'submission', .25
extendWithBoost 'superpower', 'self', attack: -1, defense: -1
extendWithBoost 'sweet-scent', 'target', evasion: -1
extendWithBoost 'swords-dance', 'self', attack: 2
extendWithBoost 'tail-glow', 'self', attack: 3
extendWithBoost 'tail-whip', 'target', defense: -1
extendWithRecoil 'take-down', .25
extendWithSecondaryEffect 'thunder', .3, ParalyzeAttachment
extendWithFangEffect 'thunder-fang', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thunderbolt', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thunderpunch', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thundershock', .1, ParalyzeAttachment
extendWithBoost 'tickle', 'target', attack: -1, defense: -1
# extendWithSecondaryEffect 'tri-attack', .1, ParalyzeAttachment
# extendWithSecondaryEffect 'twineedle', .2, PoisonAttachment
extendWithSecondaryEffect 'twister', .2, FlinchAttachment
extendWithSecondaryBoost 'v-create', 'self', defense: -1, specialDefense: -1, speed: -1
# TODO: Volt tackle should have 1/3 recoil.
extendWithSecondaryEffect 'volt-tackle', .1, ParalyzeAttachment
extendWithSecondaryEffect 'water-pulse', .2, ConfusionAttachment
extendWithSecondaryEffect 'waterfall', .2, FlinchAttachment
extendWithRecoil 'wild-charge', .25
extendWithBoost 'withdraw', 'user', defense: 1
extendWithRecoil 'wood-hammer'
extendWithBoost 'work-up', 'user', attack: 1, specialAttack: 1
extendWithSecondaryEffect 'zen-headbutt', .2, FlinchAttachment

extendMove 'acrobatics', ->
  @basePower = (battle, user, target) ->
    if !user.hasItem() then 2 * @power else @power

extendMove 'haze', ->
  @afterSuccessfulHit = (battle, user, target) ->
    user.resetBoosts()
    target.resetBoosts()
    battle.message "All stat changes were eliminated!"
