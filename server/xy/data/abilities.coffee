makeWeatherAbility = (name, weather) ->
  makeAbility name, ->
    this::switchIn = ->
      if !@battle.hasWeather(weather)
        # TODO: See if it's lengthened by rocks.
        length = 5
        @battle.setWeather(weather, length)

coffee = require 'coffee-script'
path = require('path').resolve(__dirname, '../../bw/data/abilities.coffee')
eval(coffee.compile(require('fs').readFileSync(path, 'utf8'), bare: true))

makeNormalTypeChangeAbility = (name, newType) ->
  makeAbility name, ->
    this::editMoveType = (type, target) ->
      return newType  if type == 'Normal' && @pokemon != target
      return type

makeNormalTypeChangeAbility("Aerilate", "Flying")
makeNormalTypeChangeAbility("Pixilate", "Fairy")
makeNormalTypeChangeAbility("Refrigerate", "Ice")

Ability.ShadowTag::getOpponents = ->
  opponents = @battle.getOpponents(@pokemon)
  opponents = opponents.filter((p) -> !p.hasType("Ghost"))
  opponents
