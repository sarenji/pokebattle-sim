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

  describe "Shadow Tag", ->
    it "does not affect ghosts", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Gengar")]
        team2: [Factory("Magikarp", ability: "Shadow Tag")]
      @p1.isSwitchBlocked().should.be.false
      @battle.beginTurn()
      @p1.isSwitchBlocked().should.be.false

  testAuraAbility = (name, type) ->
    describe name, ->
      it "raises base power of #{type} attacks by x1.2", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
        move = @battle.findMove (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1333)

      it "decreases #{type} attacks by x0.8 if Aura Break is on the field", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
          team2: [Factory("Magikarp", ability: "Aura Break")]
        move = @battle.findMove (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0xCCC)

      it "does nothing to moves not of #{type} type", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
        move = @battle.findMove (m) ->
          m.type != type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  testAuraAbility("Dark Aura", "Dark")
  testAuraAbility("Fairy Aura", "Fairy")

  describe "Gale Wings", ->
    it "adds 1 to the priority of the user's Flying moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Gale Wings")]
      gust = @battle.getMove("Gust")
      @p1.editPriority(0, gust).should.equal(1)

    it "does not change priority otherwise", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Gale Wings")]
      tackle = @battle.getMove("Tackle")
      @p1.editPriority(0, tackle).should.equal(0)

  describe "Bulletproof", ->
    it "makes user immune to bullet moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Bulletproof")]
      shadowBall = @battle.getMove('Shadow Ball')
      @p1.isImmune(shadowBall.type, shadowBall).should.be.true
