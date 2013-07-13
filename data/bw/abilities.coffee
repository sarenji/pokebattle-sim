{Attachment, VolatileAttachment} = require '../../server/attachment'
{Status} = require '../../server/status'
{Weather} = require '../../server/weather'
util = require '../../server/util'
require 'sugar'

@Ability = Ability = {}

makeAbility = (name, func) ->
  condensed = name.replace(/\s+/g, '')
  class Ability[condensed] extends VolatileAttachment
    name: name
    func?.call(this)

makeAbility 'Technician'
makeAbility 'Natural Cure'
makeAbility 'Guts'
makeAbility 'Flare Boost'
makeAbility 'Reckless'
makeAbility 'Iron Fist'
makeAbility 'Toxic Boost'
makeAbility 'Rivalry'
makeAbility 'Sand Force'
makeAbility 'Heatproof'
makeAbility 'Dry Skin'
makeAbility 'Sheer Force'

# TODO: Add hook to CH level.
makeAbility 'Super Luck'
makeAbility 'Battle Armor'
makeAbility 'Shell Armor'

makeAbility 'Tinted Lens'
makeAbility 'Sniper'

makeAbility 'Sticky Hold'
makeAbility 'Multitype'
makeAbility 'Damp'

makeAbility "Skill Link"

# Ability templates

makeWeatherPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsWeather = true

makeWeatherPreventionAbility("Air Lock")
makeWeatherPreventionAbility("Cloud Nine")

makeCriticalHitPreventionAbility = (name) ->
  makeAbility name, ->
    @preventsCriticalHits = true

makeCriticalHitPreventionAbility("Battle Armor")
makeCriticalHitPreventionAbility("Shell Armor")

makeWeatherSpeedAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = (battle) ->
      @doubleSpeed = battle.hasWeather(weather)

    this::informWeather = (newWeather) ->
      @doubleSpeed = (weather == newWeather)

    this::modifySpeed = (speed) ->
      if @doubleSpeed then 2 * speed else speed

makeWeatherSpeedAbility("Chlorophyll", Weather.SUN)
makeWeatherSpeedAbility("Swift Swim", Weather.RAIN)
makeWeatherSpeedAbility("Sand Rush", Weather.SAND)

makeLowHealthAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (battle, move, user, target) ->
      return 0x1000  if move.getType(battle, user, target) != type
      return 0x1000  if user.currentHP > Math.floor(user.stat('hp') / 3)
      return 0x1800

makeLowHealthAbility("Blaze", "Fire")
makeLowHealthAbility("Torrent", "Water")
makeLowHealthAbility("Overgrow", "Grass")
makeLowHealthAbility("Swarm", "Bug")

# Unique Abilities

makeAbility "Adaptability"

makeAbility "Aftermath", ->
  this::afterFaint = (battle) ->
    {pokemon, damage, move, turn} = @pokemon.lastHitBy
    if move.hasFlag('contact')
      pokemon.damage(pokemon.stat('hp') >> 2)
      battle.message "The #{@pokemon.name}'s Aftermath dealt damage to #{pokemon.name}!"

makeAbility 'Analytic', ->
  this::modifyBasePower = (battle, mmove, user, target) ->
    if !battle.hasActionsLeft() then 0x14CD else 0x1000

makeAbility "Anger Point", ->
  this::informCriticalHit = (battle) ->
    battle.message "#{@pokemon.name} maxed its Attack!"
    @pokemon.boost(attack: 12)

makeAbility "Anticipation", ->
  this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    moves = (opponent.moves  for opponent in opponents).flatten()
    for move in moves
      effectiveness = util.typeEffectiveness(move.type, @pokemon.types) > 1
      if effectiveness || move.hasFlag("ohko")
        battle.message "#{@pokemon.name} shuddered!"
        break

makeAbility "Arena Trap", ->
  this::beginTurn = this::switchIn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    for opponent in opponents
      opponent.blockSwitch()  unless opponent.isImmune(battle, "Ground")

makeAbility "Bad Dreams", ->
  this::endTurn = (battle) ->
    opponents = battle.getOpponents(@pokemon)
    # TODO: Make getOpponents return only alive pokemon
    opponents = opponents.filter((p) -> p.isAlive())
    for opponent in opponents
      continue  unless opponent.hasStatus(Status.SLEEP)
      battle.message "#{opponent.name} is tormented!"
      amount = opponent.stat('hp') >> 3
      opponent.damage(amount)

makeAbility "Color Change", ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    {type} = move
    if !move.isNonDamaging() && !target.hasType(type)
      battle.message "#{target.name}'s Color Change made it the #{type} type!"
      target.types = [ type ]

makeAbility "Compoundeyes", ->
  this::editAccuracy = (accuracy) ->
    Math.floor(1.3 * accuracy)

# Hardcoded in Pokemon#boost
makeAbility "Contrary"

makeAbility "Cursed Body", ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    return  if user.has(Attachment.Substitute)
    return  if battle.rng.next("cursed body") >= .3
    battle.message "#{user.name}'s #{move.name} was disabled!"
    user.blockMove(move)

makeAbility "Cute Charm", ->
  this::afterBeingHit = (battle, move, user, target, damage) ->
    return  if !move.hasFlag("contact")
    return  if battle.rng.next("cute charm") >= .3
    battle.message "#{user.name} fell in love!"
    user.attach(Attachment.Attract, source: target)
