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

    it "becomes a 50% chance at a +3 CH level", ->
      Move::determineCriticalHitFromLevel(3, .49).should.be.true
      Move::determineCriticalHitFromLevel(3, .5).should.be.false

    it "becomes a 100% chance at a +4 CH level", ->
      Move::determineCriticalHitFromLevel(4, .99).should.be.true
      Move::determineCriticalHitFromLevel(4, 1.0).should.be.false

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
      @battle.performMove(@p1, kingsShield)
      @battle.performMove(@p2, tackle)
      mock.verify()

    it "does not protect against non-damaging moves", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      willOWisp = @battle.getMove("Will-O-Wisp")
      mock = @sandbox.mock(willOWisp).expects('hit').once()

      @battle.recordMove(@id2, willOWisp)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, kingsShield)
      @battle.performMove(@p2, willOWisp)
      mock.verify()

    it "does not protect against attacks it is immune to", ->
      shared.create.call(this, gen: 'xy')
      @p1.types = [ 'Ghost' ]
      kingsShield = @battle.getMove("King's Shield")
      tackle = @battle.getMove("Tackle")
      mock = @sandbox.mock(tackle).expects('hit').never()

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, kingsShield)
      @battle.performMove(@p2, tackle)
      mock.verify()
      @p2.stages.should.include(attack: 0)

    it "sharply lowers attacker's Attack if move was a contact move", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, kingsShield)
      @p2.stages.attack.should.equal(0)
      @battle.performMove(@p2, tackle)
      @p2.stages.attack.should.equal(-2)

    it "does not lower attacker's Attack if move was not a contact move", ->
      shared.create.call(this, gen: 'xy')
      kingsShield = @battle.getMove("King's Shield")
      ember = @battle.getMove("Ember")

      @battle.recordMove(@id2, ember)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, kingsShield)
      @p2.stages.attack.should.equal(0)
      @battle.performMove(@p2, ember)
      @p2.stages.attack.should.equal(0)

  describe "Sticky Web", ->
    shared.shouldFailIfUsedTwice("Sticky Web", gen: 'xy')

    it "lowers a pokemon's speed by 1 when switching in", ->
      shared.create.call(this, gen: 'xy', team2: (Factory("Magikarp")  for x in [0..1]))
      stickyWeb = @battle.getMove("Sticky Web")
      @battle.performMove(@p1, stickyWeb)
      @battle.performSwitch(@p2, 1)
      @team2.first().stages.should.include(speed: -1)

    it "doesn't lower a pokemon's speed by 1 if immune to ground", ->
      shared.create.call(this, gen: 'xy', team2: [ Factory("Magikarp"), Factory("Gyarados") ])
      stickyWeb = @battle.getMove("Sticky Web")
      @battle.performMove(@p1, stickyWeb)
      @battle.performSwitch(@p2, 1)
      @team2.first().stages.should.include(speed: 0)

  describe "Rapid Spin", ->
    it "removes Sticky Web", ->
      shared.create.call(this, gen: 'xy')
      stickyWeb = @battle.getMove("Sticky Web")
      rapidSpin = @battle.getMove("Rapid Spin")
      @battle.performMove(@p1, stickyWeb)
      @team2.has(Attachment.StickyWeb).should.be.true
      @battle.performMove(@p2, rapidSpin)
      @team2.has(Attachment.StickyWeb).should.be.false

  describe "Defog", ->
    it "removes Sticky Web as well", ->
      shared.create.call(this, gen: 'xy')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Sticky Web"))
      @p2.team.has(Attachment.StickyWeb).should.be.true
      @battle.performMove(@p1, defog)
      @p2.team.has(Attachment.StickyWeb).should.be.false

    it "removes hazards from both sides of the field now", ->
      shared.create.call(this, gen: 'xy')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Sticky Web"))
      @battle.performMove(@p2, @battle.getMove("Sticky Web"))
      @p1.team.has(Attachment.StickyWeb).should.be.true
      @p2.team.has(Attachment.StickyWeb).should.be.true

      @battle.performMove(@p1, defog)
      @p1.team.has(Attachment.StickyWeb).should.be.false
      @p2.team.has(Attachment.StickyWeb).should.be.false

  describe "Knock Off", ->
    it "has x1.0 power if the pokemon has no item", ->
      shared.create.call(this, gen: 'xy')
      knockOff = @battle.getMove("Knock Off")
      knockOff.basePower(@battle, @p1, @p2).should.equal(knockOff.power)

    it "has x1.5 power if the item can be knocked off", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", item: "Leftovers")]
      knockOff = @battle.getMove("Knock Off")
      basePower = knockOff.basePower(@battle, @p1, @p2)
      basePower.should.equal Math.floor(1.5 * knockOff.power)

    it "has x1.0 power if the item cannot be knocked off", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", item: "Air Mail")]
      knockOff = @battle.getMove("Knock Off")
      knockOff.basePower(@battle, @p1, @p2).should.equal(knockOff.power)

    it "has x1.5 power if item can be knocked off but owner has Sticky Hold", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", item: "Leftovers", ability: "Sticky Hold")]
      knockOff = @battle.getMove("Knock Off")
      basePower = knockOff.basePower(@battle, @p1, @p2)
      basePower.should.equal Math.floor(1.5 * knockOff.power)

  describe "Protect-like moves", ->
    it "determines success chance using a power of 3 instead of 2", ->
      shared.create.call(this, gen: 'xy')

      for x in [0..7]
        attachment = @p1.attach(Attachment.ProtectCounter)
        attachment.successChance().should.equal Math.pow(3, x)

      attachment = @p1.attach(Attachment.ProtectCounter)
      attachment.successChance().should.equal Math.pow(2, 32)

  describe "Freeze-Dry", ->
    it "is 2x effective against Water-types", ->
      shared.create.call(this, gen: 'xy')
      @p2.types = [ "Water" ]
      freezeDry = @battle.getMove('Freeze-Dry')
      spy = @sandbox.spy(freezeDry, 'typeEffectiveness')
      @battle.performMove(@p1, freezeDry)
      spy.returned(2).should.be.true

    it "is 2x effective against Water-types with Normalize", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Normalize")]
      @p2.types = [ "Water" ]
      freezeDry = @battle.getMove('Freeze-Dry')
      spy = @sandbox.spy(freezeDry, 'typeEffectiveness')
      @battle.performMove(@p1, freezeDry)
      spy.returned(2).should.be.true

    it "is normally effective against other types", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp")]
      @p2.types = [ "Fire" ]
      freezeDry = @battle.getMove('Freeze-Dry')
      spy = @sandbox.spy(freezeDry, 'typeEffectiveness')
      @battle.performMove(@p1, freezeDry)
      spy.returned(.5).should.be.true
