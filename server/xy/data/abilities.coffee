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
