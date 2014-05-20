{Item} = require('../../server/xy/data/items')
{Pokemon} = require '../../server/xy/pokemon'
{Weather} = require('../../shared/weather')
{Attachment, Status} = require '../../server/xy/attachment'
{Move} = require '../../server/xy/move'
{Factory} = require '../factory'
util = require '../../server/xy/util'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Items:", ->
  describe "Weakness Policy", ->
    it "raises Attack and Sp. Attack by 2 if hit by a super-effective move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderbolt = @battle.getMove("Thunderbolt")
      @p1.stages.should.include(attack: 0, specialAttack: 0)
      @battle.performMove(@p2, thunderbolt)
      @p1.stages.should.include(attack: 2, specialAttack: 2)

    it "is consumed after use", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderbolt = @battle.getMove("Thunderbolt")
      @battle.performMove(@p2, thunderbolt)
      @p1.hasItem().should.be.false

    it "is not used if hit by a non-super-effective move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      ember = @battle.getMove("Ember")
      @battle.performMove(@p2, ember)
      @p1.hasItem().should.be.true
      @p1.stages.should.include(attack: 0, specialAttack: 0)

    it "is not used if hit by a super-effective move that is non-damaging", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      thunderWave = @battle.getMove("Thunder Wave")
      @battle.performMove(@p2, thunderWave)
      @p1.hasItem().should.be.true
      @p1.stages.should.include(attack: 0, specialAttack: 0)

    it "not used if the wearer is behind a substitute", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Weakness Policy')]
      @p1.attach(Attachment.Substitute, hp: 1)
      thunderbolt = @battle.getMove("Thunderbolt")
      @battle.performMove(@p2, thunderbolt)
      @p1.hasItem().should.be.true
      @p1.stages.should.include(attack: 0, specialAttack: 0)

  describe "Assault Vest", ->
    it "blocks non-damaging moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Assault Vest')]
      splash = @battle.getMove("Splash")
      @p1.isMoveBlocked(splash).should.be.true

    it "doesn't block damaging moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Assault Vest')]
      tackle = @battle.getMove("Tackle")
      @p1.isMoveBlocked(tackle).should.be.false

    it "raises special defense by 1.5", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp')]
      spDef = @p1.stat('specialDefense')
      @p1.setItem(Item.AssaultVest)
      @p1.stat('specialDefense').should.equal Math.floor(spDef * 1.5)

  describe "Gems", ->
    it "now only boosts their respective type by x1.3", ->
      shared.create.call(this, gen: 'xy')
      move = @battle.getMove('Acrobatics')
      modifier = Item.FlyingGem::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x14CD

  describe "Kee Berry", ->
    it "raises defense if hit by a physical attack", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Kee Berry')]
      @p1.stages.should.include(defense: 0)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.stages.should.include(defense: 1)

    it "is consumed after use", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Kee Berry')]
      @p1.hasItem().should.be.true
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.hasItem().should.be.false

  describe "Maranga Berry", ->
    it "raises defense if hit by a special attack", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Maranga Berry')]
      @p1.stages.should.include(specialDefense: 0)
      @battle.performMove(@p2, @battle.getMove("Ember"))
      @p1.stages.should.include(specialDefense: 1)

    it "is consumed after use", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory('Magikarp', item: 'Maranga Berry')]
      @p1.hasItem().should.be.true
      @battle.performMove(@p2, @battle.getMove("Ember"))
      @p1.hasItem().should.be.false

  describe "Safety Goggles", ->
    it "makes the user immune to weather", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", item: "Safety Goggles")]
      @p1.isWeatherDamageImmune(Weather.SAND).should.be.true
      @p1.isWeatherDamageImmune(Weather.HAIL).should.be.true

    it "makes the user immune to powder moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", item: "Safety Goggles")]
      spore = @battle.getMove("Spore")
      mock = @sandbox.mock(spore).expects('hit').never()
      @battle.performMove(@p2, spore)
      mock.verify()
