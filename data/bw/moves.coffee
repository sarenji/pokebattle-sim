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
  move = moves[name]
  # todo: error if it doesn't exist

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
      user.currentHP += amount
      # TODO: Message after drain

extendWithDrain 'absorb'
extendWithSecondaryEffect 'blaze-kick', .1, BurnAttachment
extendWithSecondaryEffect 'blizzard', .1, FreezeAttachment
extendWithSecondaryEffect 'blue-flare', .2, BurnAttachment
extendWithSecondaryEffect 'body-slam', .3, ParalyzeAttachment
extendWithSecondaryEffect 'bolt-strike', .2, ParalyzeAttachment
extendWithSecondaryEffect 'bone-club', .1, FlinchAttachment
extendWithSecondaryEffect 'bounce', .3, ParalyzeAttachment
extendWithSecondaryEffect 'confusion', .1, ConfusionAttachment
extendWithSecondaryEffect 'dark-pulse', .2, FlinchAttachment
extendWithSecondaryEffect 'discharge', .3, ParalyzeAttachment
extendWithSecondaryEffect 'dizzy-punch', .2, ConfusionAttachment
extendWithSecondaryEffect 'dragon-rush', .2, FlinchAttachment
extendWithSecondaryEffect 'dragonbreath', .3, ParalyzeAttachment
extendWithDrain 'drain-punch'
extendWithDrain 'dream-eater'
extendWithSecondaryEffect 'ember', .1, BurnAttachment
extendWithSecondaryEffect 'extrasensory', .1, FlinchAttachment
extendWithSecondaryEffect 'fire-blast', .1, BurnAttachment
extendWithFangEffect 'fire-fang', .1, BurnAttachment
extendWithSecondaryEffect 'fire-punch', .1, BurnAttachment
extendWithSecondaryEffect 'flame-wheel', .1, BurnAttachment
extendWithSecondaryEffect 'flamethrower', .1, BurnAttachment
extendWithSecondaryEffect 'flare-blitz', .1, BurnAttachment
extendWithSecondaryEffect 'force-palm', .3, ParalyzeAttachment
extendWithSecondaryEffect 'freeze-shock', .3, ParalyzeAttachment
extendWithDrain 'giga-drain'
extendWithSecondaryEffect 'gunk-shot', .3, PoisonAttachment
extendWithSecondaryEffect 'headbutt', .3, FlinchAttachment
extendWithSecondaryEffect 'heart-stamp', .3, FlinchAttachment
extendWithSecondaryEffect 'heat-wave', .1, BurnAttachment
extendWithDrain 'horn-leech'
extendWithSecondaryEffect 'hurricane', .3, ConfusionAttachment
extendWithSecondaryEffect 'hyper-fang', .1, FlinchAttachment
extendWithSecondaryEffect 'ice-beam', .1, FreezeAttachment
extendWithSecondaryEffect 'ice-burn', .3, BurnAttachment
extendWithFangEffect 'ice-fang', .1, FreezeAttachment
extendWithSecondaryEffect 'ice-punch', .3, FreezeAttachment
extendWithSecondaryEffect 'icicle-crash', .3, FlinchAttachment
extendWithSecondaryEffect 'iron-head', .3, FlinchAttachment
extendWithSecondaryEffect 'lava-plume', .3, BurnAttachment
extendWithDrain 'leech-life'
extendWithSecondaryEffect 'lick', .3, ParalyzeAttachment
extendWithDrain 'mega-drain'
extendWithSecondaryEffect 'needle-arm', .3, FlinchAttachment
extendWithSecondaryEffect 'poison-fang', .3, ToxicAttachment
extendWithSecondaryEffect 'poison-jab', .3, PoisonAttachment
extendWithSecondaryEffect 'poison-sting', .3, PoisonAttachment
extendWithSecondaryEffect 'poison-tail', .1, PoisonAttachment
extendWithSecondaryEffect 'powder-snow', .1, FreezeAttachment
extendWithSecondaryEffect 'psybeam', .1, ConfusionAttachment
extendWithSecondaryEffect 'relic-song', .1, SleepAttachment
extendWithSecondaryEffect 'rock-climb', .2, ConfusionAttachment
extendWithSecondaryEffect 'rock-slide', .3, FlinchAttachment
extendWithSecondaryEffect 'rolling-kick', .3, FlinchAttachment
extendWithSecondaryEffect 'scald', .3, BurnAttachment
extendWithSecondaryEffect 'searing-shot', .3, BurnAttachment
extendWithSecondaryEffect 'signal-beam', .1, ConfusionAttachment
extendWithSecondaryEffect 'sky-attack', .3, FlinchAttachment
extendWithSecondaryEffect 'sludge', .3, PoisonAttachment
extendWithSecondaryEffect 'sludge-bomb', .3, PoisonAttachment
extendWithSecondaryEffect 'sludge-wave', .1, PoisonAttachment
extendWithSecondaryEffect 'smog', .4, PoisonAttachment
extendWithSecondaryEffect 'snore', .3, FlinchAttachment
extendWithSecondaryEffect 'spark', .3, ParalyzeAttachment
extendWithSecondaryEffect 'steamroller', .3, FlinchAttachment
extendWithSecondaryEffect 'stomp', .3, FlinchAttachment
extendWithSecondaryEffect 'thunder', .3, ParalyzeAttachment
extendWithFangEffect 'thunder-fang', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thunderbolt', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thunderpunch', .1, ParalyzeAttachment
extendWithSecondaryEffect 'thundershock', .1, ParalyzeAttachment
# extendWithSecondaryEffect 'tri-attack', .1, ParalyzeAttachment
# extendWithSecondaryEffect 'twineedle', .2, PoisonAttachment
extendWithSecondaryEffect 'twister', .2, FlinchAttachment
extendWithSecondaryEffect 'volt-tackle', .1, ParalyzeAttachment
extendWithSecondaryEffect 'water-pulse', .2, ConfusionAttachment
extendWithSecondaryEffect 'waterfall', .2, FlinchAttachment
extendWithSecondaryEffect 'zen-headbutt', .2, FlinchAttachment

extendMove 'acrobatics', ->
  @basePower = (battle, user, target) ->
    if !user.hasItem() then 2 * @power else @power
