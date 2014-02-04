{Weather} = require '../weather'

# Retcon weather abilities to only last 5 turns.
makeWeatherAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = ->
      return  if @battle.hasWeather(weather)
      moveName = switch weather
        when Weather.SUN  then "Sunny Day"
        when Weather.RAIN then "Rain Dance"
        when Weather.SAND then "Sandstorm"
        when Weather.HAIL then "Hail"
        else throw new Error("#{weather} ability not supported.")

      move = @battle.getMove(moveName)
      move.changeWeather(@battle, @pokemon)

# Import old abilities

coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/abilities.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

# New ability interfaces

makeNormalTypeChangeAbility = (name, newType) ->
  makeAbility name, ->
    this::editMoveType = (type, target) ->
      return newType  if type == 'Normal' && @pokemon != target
      return type

    this::modifyBasePower = (move, target) ->
      return 0x1555  if move.type == 'Normal'
      return 0x1000

makeNormalTypeChangeAbility("Aerilate", "Flying")
makeNormalTypeChangeAbility("Pixilate", "Fairy")
makeNormalTypeChangeAbility("Refrigerate", "Ice")

makeAuraAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (move, target) ->
      return 0x1000  if move.getType(@battle, @pokemon, target) != type
      for pokemon in @battle.getActiveAlivePokemon()
        return 0xC00  if pokemon.hasAbility("Aura Break")
      return 0x1555

makeAuraAbility("Dark Aura", "Dark")
makeAuraAbility("Fairy Aura", "Fairy")

# New unique abilities

# TODO: Aroma Veil
makeAbility "Aroma Veil"

# Implemented in makeAuraAbility
makeAbility "Aura Break"

makeAbility 'Bulletproof', ->
  this::isImmune = (type, move) ->
    return true  if move?.hasFlag('bullet')

# TODO: Cheek Pouch
makeAbility "Cheek Pouch"

# TODO: Competitive
makeAbility "Competitive"

# TODO: Flower Veil
makeAbility "Flower Veil"

makeAbility "Fur Coat", ->
  this::modifyBasePowerTarget = (move) ->
    if move.isPhysical() then 0x800 else 0x1000

makeAbility 'Gale Wings', ->
  this::editPriority = (priority, move) ->
    # TODO: Test if Gale Wings works with Hidden Power Flying.
    return priority + 1  if move.type == 'Flying'
    return priority

makeAbility "Gooey", ->
  this::afterBeingHit = (move, user) ->
    user.boost(speed: -1)  if move.hasFlag("contact")

# TODO: Grass Pelt
makeAbility "Grass Pelt"

# TODO: Magician
makeAbility "Magician"

makeAbility 'Mega Launcher', ->
  this::modifyBasePower = (move, target) ->
    return 0x1800  if move.hasFlag("pulse")
    return 0x1000

makeAbility 'Parental Bond', ->
  this::calculateNumberOfHits = (move, targets) ->
    # Do nothing if this move is a multi-hit move or has multiple targets.
    return  if move.minHits != 1 || targets.length > 1
    return 2

  this::modifyDamage = (move, target, hitNumber) ->
    return 0x800  if hitNumber == 2 && move.maxHits == 1
    return 0x1000

makeAbility 'Protean', ->
  this::beforeMove = (move, user, targets) ->
    type = move.getType(@battle, user, targets[0])
    return  if user.types.length == 1 && user.types[0] == type
    user.types = [ type ]
    @battle.message "#{user.name} changed into the #{type} type!"

makeAbility 'Stance Change', ->
  this::beforeMove = (move, user, targets) ->
    newForme = switch
      when !move.isNonDamaging() then "blade"
      when move == @battle.getMove("King's Shield") then "default"
    if newForme && !@pokemon.isInForme(newForme)
      @pokemon.changeForme(newForme)
      humanized = (if newForme == "blade" then "Blade" else "Shield")
      @battle.message("Changed to #{humanized} Forme!")
    true

  this::switchOut = ->
    @pokemon.changeForme("default")  if !@pokemon.isInForme("default")

makeAbility "Strong Jaw", ->
  this::modifyBasePower = (move) ->
    return 0x1800  if move.hasFlag("bite")
    return 0x1000

# TODO: Sweet Veil (2v2)
makeAttachmentImmuneAbility "Sweet Veil", [Attachment.Sleep]

# TODO: Symbiosis
makeAbility "Symbiosis"

makeAbility "Tough Claws", ->
  this::modifyBasePower = (move) ->
    return 0x1547  if move.hasFlag("contact")
    return 0x1000
