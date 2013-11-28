# Retcon weather abilities to only last 5 turns.
makeWeatherAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = ->
      if !@battle.hasWeather(weather)
        # TODO: See if it's lengthened by rocks.
        length = 5
        @battle.setWeather(weather, length)

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

    this::modifyBasePower = (move, user, target) ->
      return 0x1555  if move.getType(@battle, user, target) == 'Normal'
      return 0x1000

makeNormalTypeChangeAbility("Aerilate", "Flying")
makeNormalTypeChangeAbility("Pixilate", "Fairy")
makeNormalTypeChangeAbility("Refrigerate", "Ice")

makeAuraAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (move, user, target) ->
      return 0x1000  if move.getType(@battle, user, target) != type
      for pokemon in @battle.getActiveAlivePokemon()
        return 0xC00  if pokemon.hasAbility("Aura Break")
      return 0x1555

makeAuraAbility("Dark Aura", "Dark")
makeAuraAbility("Fairy Aura", "Fairy")

# New unique abilities

# TODO: Aroma Veil

# Implemented in makeAuraAbility
makeAbility "Aura Break"

makeAbility 'Bulletproof', ->
  this::isImmune = (type, move) ->
    return true  if move?.hasFlag('bullet')

# TODO: Cheek Pouch

# TODO: Competitive

# TODO: Flower Veil

# TODO: Fur Coat

makeAbility 'Gale Wings', ->
  this::editPriority = (priority, move) ->
    # TODO: Test if Gale Wings works with Hidden Power Flying.
    return priority + 1  if move.type == 'Flying'
    return priority

# TODO: Gooey

# TODO: Grass Pelt

# TODO: Magician

# TODO: Mega Launcher

makeAbility 'Parental Bond', ->
  this::calculateNumberOfHits = (move, targets) ->
    # Do nothing if this move is a multi-hit move or has multiple targets.
    return  if move.minHits != 1 || targets.length > 1
    return 2

  this::modifyDamage = (move, target, hitNumber) ->
    return 0x800  if hitNumber == 2 && move.maxHits == 1
    return 0x1000

# TODO: Protean

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

# TODO: Strong Jaw

# TODO: Sweet Veil

# TODO: Symbiosis

makeAbility "Tough Claws", ->
  this::modifyBasePower = (move) ->
    return 0x1547  if move.hasFlag("contact")
    return 0x1000

# Retcons

Ability.ShadowTag::getOpponents = ->
  opponents = @battle.getOpponents(@pokemon)
  opponents = opponents.filter((p) -> !p.hasType("Ghost"))
  opponents
