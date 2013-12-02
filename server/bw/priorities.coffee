{Ability} = require('./data/abilities')
{Item} = require('./data/items')
{Attachment, Status} = require('./attachment')

Priorities = Priorities ? {}

Priorities.beforeMove ?= [
  # Things that should happen no matter what
  Attachment.Pursuit
  Attachment.Fling

  # Order-dependent
  Status.Freeze
  Status.Sleep
  Ability.Truant
  Attachment.Disable
  Attachment.ImprisonPrevention
  # TODO: Heal Block
  Attachment.Confusion
  Attachment.Flinch
  Attachment.Taunt
  Attachment.GravityPokemon
  Attachment.Attract
  Status.Paralyze

  # Things that should happen only if the move starts executing
  Attachment.FocusPunch
  Attachment.Recharge
  Attachment.Metronome
  Attachment.DestinyBond
  Attachment.Grudge
  Attachment.Rage
  Attachment.Charging
  Attachment.FuryCutter
  Item.ChoiceBand
  Item.ChoiceScarf
  Item.ChoiceSpecs
]

Priorities.endTurn ?= [
  # Non-order-dependent
  Attachment.Flinch
  Attachment.Roost
  Attachment.MicleBerry
  Attachment.LockOn
  Attachment.Recharge
  Attachment.Momentum
  Attachment.MeFirst
  Attachment.Charge
  Attachment.ProtectCounter
  Attachment.Protect
  Attachment.Endure
  Attachment.Pursuit
  Attachment.Present
  Attachment.MagicCoat
  Attachment.EchoedVoice
  Attachment.Rampage
  Attachment.Fling
  Attachment.DelayedAttack
  Ability.SlowStart

  # Order-dependent
  Ability.RainDish
  Ability.DrySkin
  Ability.SolarPower
  Ability.IceBody

  # Team attachments
  Attachment.FutureSight
  Attachment.DoomDesire
  Attachment.Wish

  # TODO: Fire Pledge/Grass Pledge
  Ability.ShedSkin
  Ability.Hydration
  Ability.Healer
  Item.Leftovers
  Item.BlackSludge

  Attachment.AquaRing
  Attachment.Ingrain
  Attachment.LeechSeed

  Status.Burn
  Status.Toxic
  Status.Poison
  Ability.PoisonHeal
  Attachment.Nightmare

  Attachment.Curse
  Attachment.Trap
  Attachment.Taunt
  Attachment.Encore
  Attachment.Disable
  Attachment.MagnetRise
  Attachment.Telekinesis
  # TODO: Attachment.HealBlock
  Attachment.Embargo
  Attachment.Yawn
  Attachment.PerishSong
  Attachment.Reflect
  Attachment.LightScreen
  Attachment.Screen
  # Attachment.Safeguard
  # Attachment.Mist
  # Attachment.Tailwind
  Attachment.LuckyChant
  # TODO: Pledge moves
  Attachment.Gravity
  Attachment.GravityPokemon
  Attachment.TrickRoom
  # Attachment.WonderRoom
  # Attachment.MagicRoom
  Attachment.Uproar
  Ability.SpeedBoost
  Ability.BadDreams
  Ability.Harvest
  Ability.Moody
  Item.ToxicOrb
  Item.FlameOrb
  Item.StickyBarb
  # Ability.ZenMode
]


@orderByPriority = orderByPriority = (arrayOfAttachments, eventName) ->
  array = arrayOfAttachments.map (attachment) ->
    [ attachment, Priorities[eventName].indexOf(attachment.constructor) ]
  array.sort((a, b) -> a[1] - b[1])
  array.map((a) -> a[0])

queryUntil = (funcName, conditional, attachments, args...) ->
  for attachment in orderByPriority(attachments, funcName)
    continue  if !attachment.valid()
    if funcName of attachment
      result = attachment[funcName].apply(attachment, args)
    break  if conditional(result)
  result

@query = (funcName, args...) ->
  queryUntil(funcName, (-> false), args...)

@queryUntilTrue = (funcName, args...) ->
  conditional = (result) -> result == true
  queryUntil(funcName, conditional, args...)

@queryUntilFalse = (funcName, args...) ->
  conditional = (result) -> result == false
  queryUntil(funcName, conditional, args...)

@queryUntilNotNull = (funcName, args...) ->
  conditional = (result) -> result?
  queryUntil(funcName, conditional, args...)

@queryChain = (funcName, result, attachments, args...) ->
  for attachment in orderByPriority(attachments, funcName)
    result = attachment[funcName].call(attachment, result, args...)  if funcName of attachment
  result

@queryModifiers = (funcName, attachments, args...) ->
  result = 0x1000
  for attachment in orderByPriority(attachments, funcName)
    continue  unless funcName of attachment
    modifier = attachment[funcName](args...)
    result = Math.floor((result * modifier + 0x800) / 0x1000)
  result

@Priorities = Priorities
