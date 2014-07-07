{_} = require('underscore')
{Ability} = require('./data/abilities')
{Item} = require('./data/items')
{Attachment, Status} = require('./attachment')

module.exports = Priorities = {}

Priorities.beforeMove ?= [
  # Things that should happen no matter what
  Attachment.Pursuit
  Attachment.Fling
  Attachment.DestinyBond

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
  Attachment.Grudge
  Attachment.Rage
  Attachment.Charging
  Attachment.FuryCutter
  Item.ChoiceBand
  Item.ChoiceScarf
  Item.ChoiceSpecs
  Ability.MoldBreaker
  Ability.Teravolt
  Ability.Turboblaze
]

Priorities.endTurn ?= [
  # Non-order-dependent
  Attachment.AbilityCancel
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
  # Attachment.Mist
  Attachment.Safeguard
  Attachment.Tailwind
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

Priorities.shouldBlockExecution ?= [
  # Type-immunity/Levitate (Move#use)
  # Wide Guard/Quick Guard
  Attachment.Protect
  Attachment.MagicCoat
  # TODO: Reimplement Magic Bounce as its own thing
  Ability.DrySkin
  Ability.FlashFire
  Ability.Lightningrod
  Ability.MotorDrive
  Ability.SapSipper
  Ability.Soundproof
  Ability.StormDrain
  Ability.Telepathy
  Ability.VoltAbsorb
  Ability.WaterAbsorb
  Ability.WonderGuard
  Attachment.Ingrain
  Attachment.Charging
  Attachment.SmackDown
  Attachment.Substitute
]

Priorities.isImmune ?= [
  Attachment.GravityPokemon  # Gravity overrides Ground-type immunities.
  Attachment.Ingrain
  Attachment.SmackDown
  Item.IronBall
  Attachment.Telekinesis
  Ability.Levitate
  Attachment.MagnetRise
  Item.AirBalloon
  Attachment.Identify
  Ability.Soundproof
]
