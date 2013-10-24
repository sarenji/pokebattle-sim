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

makeNormalTypeChangeAbility("Aerilate", "Flying")
makeNormalTypeChangeAbility("Pixilate", "Fairy")
makeNormalTypeChangeAbility("Refrigerate", "Ice")

makeAuraAbility = (name, type) ->
  makeAbility name, ->
    this::modifyBasePower = (move, user, target) ->
      return 0x1000  if move.getType(@battle, user, target) != type
      for pokemon in @battle.getActiveAlivePokemon()
        return 0xCCC  if pokemon.hasAbility("Aura Break")
      return 0x1333

makeAuraAbility("Dark Aura", "Dark")
makeAuraAbility("Fairy Aura", "Fairy")

# New unique abilities

# Implemented in makeAuraAbility
makeAbility "Aura Break"

makeAbility 'Bulletproof', ->
  this::isImmune = (type, move) ->
    return true  if move?.hasFlag('bullet')

makeAbility 'Gale Wind', ->
  this::editPriority = (priority, move) ->
    # TODO: Test if Gale Wind works with Hidden Power Flying.
    return priority + 1  if move.type == 'Flying'
    return priority

# Retcons

Ability.ShadowTag::getOpponents = ->
  opponents = @battle.getOpponents(@pokemon)
  opponents = opponents.filter((p) -> !p.hasType("Ghost"))
  opponents
