{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../server/xy/weather')
{Ability} = require '../../server/xy/data/abilities'
util = require '../../server/xy/util'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'

require '../helpers'

describe "BW Abilities:", ->
  testWeatherAbility = (name, weather) ->
    describe name, ->
      it "causes #{weather} that ends after 5 turns", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        @battle.weatherDuration.should.equal(5)

      it "does not activate if the weather is already #{weather}", ->
        shared.build(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        @battle.setWeather(weather, 2)
        @controller.beginBattle()
        @battle.weatherDuration.should.equal(2)

  testWeatherAbility("Drizzle", Weather.RAIN)
  testWeatherAbility("Drought", Weather.SUN)
  testWeatherAbility("Sand Stream", Weather.SAND)
  testWeatherAbility("Snow Warning", Weather.HAIL)
