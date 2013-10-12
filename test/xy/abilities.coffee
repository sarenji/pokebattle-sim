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

  testNormalTypeChangeAbility = (name, type) ->
    describe name, ->
      it "changes Normal-type moves used by attacker to #{type}-type", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        spy = @sandbox.spy(@p1, 'editMoveType')
        tackle = @battle.getMove('Tackle')
        @battle.performMove(@id1, tackle)
        spy.returned(type).should.be.true

      it "does not change non-Normal-type moves used by attacker", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        spy = @sandbox.spy(@p1, 'editMoveType')
        ember = @battle.getMove('Ember')
        @battle.performMove(@id1, ember)
        spy.returned(type).should.be.false
        spy.returned(ember.type).should.be.true

  testNormalTypeChangeAbility("Aerilate", "Flying")
  testNormalTypeChangeAbility("Pixilate", "Fairy")
  testNormalTypeChangeAbility("Refrigerate", "Ice")
