{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../server/xy/weather')
{Move} = require('../../server/xy/move')
util = require '../../server/xy/util'
{Protocol} = require '../../shared/protocol'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Moves:", ->
  describe "a critical hit", ->
    it "multiplies damage by 1.5x", ->
      Move::criticalMultiplier.should.equal(1.5)

  describe "Dragon Pulse", ->
    it "has 85 base power now", ->
      shared.create.call(this, gen: 'xy')
      @battle.getMove('Dragon Pulse').power.should.equal(85)

  describe 'Hidden Power', ->
    it "always has 60 base power", ->
      shared.create.call(this, gen: 'xy')
      hiddenPower = @battle.getMove('Hidden Power')
      hiddenPower.power.should.equal(60)
      hiddenPower.basePower(@battle, @p1, @p2).should.equal(60)

  describe "Facade", ->
    it "does not cut attack in half when burned", ->
      shared.create.call(this, gen: 'xy')
      facade = @battle.getMove('Facade')
      facade.burnCalculation(@p1).should.equal(1)
      @p1.attach(Status.Burn)
      facade.burnCalculation(@p1).should.equal(1)

  describe "King's Shield", ->
    it "protects against attacks", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      tackle = @battle.getMove("Tackle")
      mock = @sandbox.mock(tackle).expects('hit').never()

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@id1, kingsShield)
      @battle.performMove(@id2, tackle)
      mock.verify()

    it "does not protect against non-damaging moves", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      willOWisp = @battle.getMove("Will-O-Wisp")
      mock = @sandbox.mock(willOWisp).expects('hit').once()

      @battle.recordMove(@id2, willOWisp)
      @battle.determineTurnOrder()
      @battle.performMove(@id1, kingsShield)
      @battle.performMove(@id2, willOWisp)
      mock.verify()

    it "sharply lowers attacker's Attack if move was a contact move", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@id1, kingsShield)
      @p2.stages.attack.should.equal(0)
      @battle.performMove(@id2, tackle)
      @p2.stages.attack.should.equal(-2)

    it "does not lower attacker's Attack if move was not a contact move", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      ember = @battle.getMove("Ember")

      @battle.recordMove(@id2, ember)
      @battle.determineTurnOrder()
      @battle.performMove(@id1, kingsShield)
      @p2.stages.attack.should.equal(0)
      @battle.performMove(@id2, ember)
      @p2.stages.attack.should.equal(0)

  describe "Sticky Web", ->
    shared.shouldFailIfUsedTwice("Sticky Web", gen: 'xy')

    it "lowers a pokemon's speed by 1 when switching in", ->
      shared.create.call(this, gen: 'xy', team2: (Factory("Magikarp")  for x in [0..1]))
      stickyWeb = @battle.getMove("Sticky Web")
      @battle.performMove(@id1, stickyWeb)
      @battle.performSwitch(@id2, 1)
      @team2.first().stages.should.include(speed: -1)

    it "doesn't lower a pokemon's speed by 1 if immune to ground", ->
      shared.create.call(this, gen: 'xy', team2: [ Factory("Magikarp"), Factory("Gyarados") ])
      stickyWeb = @battle.getMove("Sticky Web")
      @battle.performMove(@id1, stickyWeb)
      @battle.performSwitch(@id2, 1)
      @team2.first().stages.should.include(speed: 0)
