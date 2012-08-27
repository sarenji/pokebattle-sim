{ModifierChain} = require './modifier_chain'
{Status} = require './status'

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
  if user.hasAbility('Tinted Lens') && move.typeEffectiveness(target) < 1
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
  if (user.hasAbility('Solid Rock') || user.hasAbility('Filter'))\
      && move.typeEffectiveness(target) > 1
    return 0xC00
  return 0x1000

# TODO: Metronome item modifier.

# Expert belt modifier.
finalModifier.add 80, (move, battle, user, target) ->
  if user.hasItem('Expert Belt') && move.typeEffectiveness(target) > 1
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
                                       move.spectra == 'special'
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
  # TODO: implement isPunchingMove()
  if user.hasAbility('Iron Fist') && move.isPunchingMove()
    return 0x1333
  return 0x1000

# Toxic Boost modifier.
basePowerModifier.add 60, (move, battle, user, target) ->
  if user.hasAbility('Toxic Boost') && user.hasStatus(Status.POISON) &&
      move.spectra == 'physical'
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
  if user.hasAbility('Sand Force') && move.type in ['Rock', 'Ground', 'Steel']
    return 0x14CD
  return 0x1000

# Heatproof modifier.
basePowerModifier.add 90, (move, battle, user, target) ->
  if target.hasAbility('Heatproof') && move.type == 'Fire'
    return 0x800
  return 0x1000

# Dry Skin modifier.
basePowerModifier.add 100, (move, battle, user, target) ->
  if target.hasAbility('Dry Skin') && move.type == 'Fire'
    return 0x1400
  return 0x1000

# Sheer Force modifier.
basePowerModifier.add 110, (move, battle, user, target) ->
  if target.hasAbility('Sheer Force') && move.sheerForceable # TODO: real name
    return 0x14CD
  return 0x1000

# TODO: The rest of the base power modifiers.

@stabModifier = stabModifier = new ModifierChain()

stabModifier.add 10, (move, battle, user, target) ->
  if user.hasAbility('Adaptability') && user.hasType(move.type)
    return [0x2000, true]
  return 0x1000

stabModifier.add 20, (move, battle, user, target) ->
  if user.hasType(move.type)
    return 0x1800
  return 0x1000
