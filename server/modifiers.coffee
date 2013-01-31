{ModifierChain} = require './modifier_chain'
{Status} = require './status'

# TODO: Pass in an array of things with basePowerModifier defined instead.

@finalModifier = finalModifier = new ModifierChain()

# TODO: Reflect modifier.
# TODO: Light Screen modifier.

# Multiscale modifier.
finalModifier.add 30, (move, battle, user, target) ->
  if target.hasAbility('Multiscale') && target.currentHP == target.stat('hp')
    return 0x800
  return 0x1000

# Tinted lens modifier.
finalModifier.add 40, (move, battle, user, target) ->
  effectiveness = move.typeEffectiveness(battle, user, target)
  if user.hasAbility('Tinted Lens') && effectiveness < 1
    return 0x2000
  return 0x1000

# TODO: If an ally has Friend Guard, modifier is 0xC00.

# Sniper modifier.
finalModifier.add 60, (move, battle, user, target) ->
  if user.hasAbility('Sniper') && move.willCriticalHit()
    return 0x1800
  return 0x1000

# Solid Rock/Filter modifier.
finalModifier.add 70, (move, battle, user, target) ->
  effectiveness = move.typeEffectiveness(battle, user, target)
  if (user.hasAbility('Solid Rock') || user.hasAbility('Filter'))\
      && effectiveness > 1
    return 0xC00
  return 0x1000

# TODO: Metronome item modifier.

# Expert belt modifier.
finalModifier.add 80, (move, battle, user, target) ->
  effectiveness = move.typeEffectiveness(battle, user, target)
  if user.hasItem('Expert Belt') && effectiveness > 1
    return 0x1333
  return 0x1000

# Life Orb modifier.
finalModifier.add 90, (move, battle, user, target) ->
  if user.hasItem('Life Orb')
    return 0x14CC
  return 0x1000

# TODO: Damage-lowering berry modifier.
# TODO: Stomp + Minimize modifier.
# TODO: Earthquake + Dig modifier.
# TODO: Surf + Dive modifier.
# TODO: Steamroller + Minimize modifier.

@basePowerModifier = basePowerModifier = new ModifierChain()

# Technician modifier.
basePowerModifier.add 10, (move, battle, user, target) ->
  if user.hasAbility('Technician') && move.power <= 60
    return 0x1800
  return 0x1000

# Flare Boost modifier.
basePowerModifier.add 20, (move, battle, user, target) ->
  if user.hasAbility("Flare Boost") && user.hasStatus(Status.BURN) &&
                                       move.isSpecial()
    return 0x1800
  return 0x1000

# Analytic modifier.
basePowerModifier.add 30, (move, battle, user, target) ->
  if user.hasAbility('Analytic') && target.hasMoved() &&
        move.name not in ['Future Sight', 'Doom Desire']
      return 0x14CD
  return 0x1000

# Reckless modifier.
basePowerModifier.add 40, (move, battle, user, target) ->
  if user.hasAbility('Reckless') && (move.recoil || move.name == 'Jump Kick' ||
                                     move.name == 'Hi Jump Kick')
    return 0x1333
  return 0x1000

# Iron Fist modifier.
basePowerModifier.add 50, (move, battle, user, target) ->
  if user.hasAbility('Iron Fist') && move.hasFlag("punch")
    return 0x1333
  return 0x1000

# Toxic Boost modifier.
basePowerModifier.add 60, (move, battle, user, target) ->
  if user.hasAbility('Toxic Boost') && user.hasStatus(Status.POISON) &&
      move.isPhysical()
    return 0x1800
  return 0x1000

# Rivalry modifier.
basePowerModifier.add 70, (move, battle, user, target) ->
  if !user.hasAbility('Rivalry')
    0x1000
  else if !user.gender? || !target.gender?
    0x1000
  else if user.gender == target.gender
    0x1400
  else
    0xC00

# Sand Force modifier.
basePowerModifier.add 80, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if user.hasAbility('Sand Force') && type in ['Rock', 'Ground', 'Steel']
    return 0x14CD
  return 0x1000

# Heatproof modifier.
basePowerModifier.add 90, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if target.hasAbility('Heatproof') && type == 'Fire'
    return 0x800
  return 0x1000

# Dry Skin modifier.
basePowerModifier.add 100, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if target.hasAbility('Dry Skin') && type == 'Fire'
    return 0x1400
  return 0x1000

# Sheer Force modifier.
basePowerModifier.add 110, (move, battle, user, target) ->
  if target.hasAbility('Sheer Force') && move.sheerForceable # TODO: real name
    return 0x14CD
  return 0x1000

# Various item modifiers
basePowerModifier.add 120, (move, battle, user, target) ->
  if user.item?
    return user.item.basePowerModifier(move, battle, user, target)
  return 0x1000

# TODO: The rest of the base power modifiers.

@stabModifier = stabModifier = new ModifierChain()

stabModifier.add 10, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if user.hasAbility('Adaptability') && user.hasType(type)
    return [0x2000, true]
  return 0x1000

stabModifier.add 20, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if user.hasType(type)
    return 0x1800
  return 0x1000


@attackStatModifier = attackStatModifier = new ModifierChain()

# TODO: Test these
# TODO: Move these into attackStatModifiers.
# Thick Fat
attackStatModifier.add 10, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if target.hasAbility('Thick Fat') && type in ['Fire', 'Ice']
    return 0x800
  return 0x1000

# Torrent
attackStatModifier.add 20, (move, battle, user, target) ->
  type = move.getType(battle, user, target)
  if user.hasAbility('Torrent') && type == 'Water' &&
      user.currentHP <= Math.floor(user.stat('hp') / 3)
    return 0x800
  return 0x1000

# Guts
attackStatModifier.add 30, (move, battle, user, target) ->
  if user.hasAbility('Guts') && user.hasStatus() && move.isPhysical()
    return 0x1800
  return 0x1000

# TODO: Swarm (Implement when you make Abilities)
# TODO: Overgrow
# TODO: Plus/Minus
# TODO: Blaze

# Defeatist
attackStatModifier.add 40, (move, battle, user, target) ->
  if user.hasAbility('Defeatist') && user.currentHP <= Math.floor(user.stat('hp') / 2)
    return 0x800
  return 0x1000

# Pure Power and Huge Power
attackStatModifier.add 50, (move, battle, user, target) ->
  if user.hasAbility('Huge Power') || user.hasAbility('Pure Power')
    return 0x2000
  return 0x1000

# Solar Power
attackStatModifier.add 60, (move, battle, user, target) ->
  if user.hasAbility('Solar Power') && battle.hasWeather('Sun') && move.isSpecial()
    return 0x1800
  return 0x1000

# Solar Power
attackStatModifier.add 60, (move, battle, user, target) ->
  if user.hasAbility('Hustle') && move.isPhysical()
    return 0x1800
  return 0x1000

# TODO: Flash Fire activated
# TODO: Slow start
# TODO: Flower Gift

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.species in ['Cubone', 'Marowak'] && user.hasItem('Thick Club') && move.isPhysical()
    return 0x2000
  return 0x1000

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.species == 'Clamperl' && user.hasItem('DeepSeaTooth') && move.isSpecial()
    return 0x2000
  return 0x1000

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.species == 'Pikachu' && user.hasItem('Light Ball')
    return 0x2000
  return 0x1000

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.species in ['Latias', 'Latios'] && user.hasItem('Soul Dew') && move.isSpecial()
    return 0x2000
  return 0x1000

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.hasItem('Choice Band') && move.isPhysical()
    return 0x1800
  return 0x1000

attackStatModifier.add 60, (move, battle, user, target) ->
  if user.hasItem('Choice Specs') && move.isSpecial()
    return 0x1800
  return 0x1000
