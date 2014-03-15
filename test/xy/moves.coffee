{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../shared/weather')
{Move} = require('../../server/xy/move')
util = require '../../server/xy/util'
{Protocol} = require '../../shared/protocol'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

require '../helpers'

describe "XY Moves:", ->
  # Test every single move for their primary effects.
  shared.testEveryMove(Battle::MoveList, 'xy')

  describe "a critical hit", ->
    it "multiplies damage by 1.5x", ->
      Move::criticalMultiplier.should.equal(1.5)

    it "becomes a 50% chance at a +3 CH level", ->
      Move::determineCriticalHitFromLevel(3, .49).should.be.true
      Move::determineCriticalHitFromLevel(3, .5).should.be.false

    it "becomes a 100% chance at a +4 CH level", ->
      Move::determineCriticalHitFromLevel(4, .99).should.be.true
      Move::determineCriticalHitFromLevel(4, 1.0).should.be.false

  describe "a powder move", ->
    it "does not affect Grass-types", ->
      shared.create.call(this, gen: 'xy')
      powderMove = @battle.findMove((m) -> m.hasFlag("powder"))
      @p2.types.push("Grass")

      mock1 = @sandbox.mock(powderMove).expects('hit').never()
      mock2 = @sandbox.mock(powderMove).expects('fail').once()
      @battle.performMove(@p1, powderMove)
      mock1.verify()
      mock2.verify()

    it "affects non-Grass-types", ->
      shared.create.call(this, gen: 'xy')
      powderMove = @battle.findMove((m) -> m.hasFlag("powder"))
      @p2.types = [ "Normal" ]

      mock1 = @sandbox.mock(powderMove).expects('hit').once()
      mock2 = @sandbox.mock(powderMove).expects('fail').never()
      @battle.performMove(@p1, powderMove)
      mock1.verify()
      mock2.verify()

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

  describe "Spiky Shield", ->
    it "protects against attacks", ->
      shared.create.call(this, gen: 'xy')
      spikyShield = @battle.getMove("Spiky Shield")
      tackle = @battle.getMove("Tackle")
      mock = @sandbox.mock(tackle).expects('hit').never()

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, spikyShield)
      @battle.performMove(@p2, tackle)
      mock.verify()

    it "protects against non-damaging moves", ->
      shared.create.call(this, gen: 'xy')
      spikyShield = @battle.getMove("Spiky Shield")
      willOWisp = @battle.getMove("Will-O-Wisp")
      mock = @sandbox.mock(willOWisp).expects('hit').never()

      @battle.recordMove(@id2, willOWisp)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, spikyShield)
      @battle.performMove(@p2, willOWisp)
      mock.verify()

    it "does not protect against attacks it is immune to", ->
      shared.create.call(this, gen: 'xy')
      @p1.types = [ 'Ghost' ]
      spikyShield = @battle.getMove("Spiky Shield")
      tackle = @battle.getMove("Tackle")
      mock = @sandbox.mock(tackle).expects('hit').never()

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, spikyShield)
      @battle.performMove(@p2, tackle)
      mock.verify()
      @p2.stages.should.include(attack: 0)

    it "damages attacker by 1/8 if move was a contact move", ->
      shared.create.call(this, gen: 'xy')
      spikyShield = @battle.getMove("Spiky Shield")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, spikyShield)
      @p2.currentHP.should.not.be.lessThan(@p2.stat('hp'))
      @battle.performMove(@p2, tackle)
      (@p2.stat('hp') - @p2.currentHP).should.equal(@p2.stat('hp') >> 3)

    it "does not damage attacker if move was not a contact move", ->
      shared.create.call(this, gen: 'xy')
      spikyShield = @battle.getMove("Spiky Shield")
      ember = @battle.getMove("Ember")

      @battle.recordMove(@id2, ember)
      @battle.determineTurnOrder()
      @battle.performMove(@p1, spikyShield)
      @p2.currentHP.should.not.be.lessThan(@p2.stat('hp'))
      @battle.performMove(@p2, ember)
      @p2.currentHP.should.not.be.lessThan(@p2.stat('hp'))

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

    it "removes screens from only the target's side of the field", ->
      shared.create.call(this, gen: 'xy')
      defog = @battle.getMove("Defog")
      @battle.performMove(@p1, @battle.getMove("Reflect"))
      @battle.performMove(@p1, @battle.getMove("Light Screen"))
      @battle.performMove(@p2, @battle.getMove("Reflect"))
      @battle.performMove(@p2, @battle.getMove("Light Screen"))
      @p1.team.has(Attachment.Reflect).should.be.true
      @p1.team.has(Attachment.LightScreen).should.be.true
      @p2.team.has(Attachment.Reflect).should.be.true
      @p2.team.has(Attachment.LightScreen).should.be.true

      @battle.performMove(@p1, defog)
      @p1.team.has(Attachment.Reflect).should.be.true
      @p1.team.has(Attachment.LightScreen).should.be.true
      @p2.team.has(Attachment.Reflect).should.be.false
      @p2.team.has(Attachment.LightScreen).should.be.false

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

  describe "Substitute", ->
    it "is bypassed by voice moves", ->
      shared.create.call(this, gen: 'xy')
      @p2.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      voiceMove = @battle.findMove (m) ->
        !m.isNonDamaging() && m.hasFlag("sound")
      spy = @sandbox.spy(voiceMove, 'hit')
      @battle.performMove(@p1, voiceMove)
      spy.calledOnce.should.be.true
      @p2.currentHP.should.be.lessThan(@p2.stat('hp'))

    it "is bypassed by Infiltrator", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Magikarp", ability: "Infiltrator")]
      @p2.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      tackle = @battle.getMove("Tackle")
      spy = @sandbox.spy(tackle, 'hit')
      @battle.performMove(@p1, tackle)
      spy.calledOnce.should.be.true
      @p2.currentHP.should.be.lessThan(@p2.stat('hp'))

    it "is bypassed by Infiltrator even on status moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Magikarp", ability: "Infiltrator")]
      @p2.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      toxic = @battle.getMove("Toxic")
      spy = @sandbox.spy(toxic, 'hit')
      @battle.performMove(@p1, toxic)
      spy.calledOnce.should.be.true
      @p2.has(Status.Toxic).should.be.true

    it "does not block Knock Off + Infiltrator", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Magikarp", ability: "Infiltrator")]
        team2: [ Factory("Magikarp", item: "Leftovers")]
      @p2.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      knockOff = @battle.getMove("Knock Off")
      spy = @sandbox.spy(knockOff, 'hit')
      @battle.performMove(@p1, knockOff)
      spy.calledOnce.should.be.true
      @p2.hasItem().should.be.false

    it "does not block secondary effects + Infiltrator", ->
      shared.create.call this,
        gen: 'xy'
        team1: [ Factory("Magikarp", ability: "Infiltrator")]
      shared.biasRNG.call(this, "next", "secondary effect", 0)  # always burn
      @p2.attach(Attachment.Substitute, hp: (@p1.currentHP >> 2))
      flamethrower = @battle.getMove('Flamethrower')
      spy = @sandbox.spy(flamethrower, 'hit')
      @battle.performMove(@p1, flamethrower)
      spy.calledOnce.should.be.true
      @p2.has(Status.Burn).should.be.true

  describe "Phantom Force", ->
    it "chooses the player's next action for them", ->
      shared.create.call(this, gen: 'xy')
      move = @battle.getMove("Phantom Force")
      @p1.moves = [ move ]

      @battle.recordMove(@id1, move)
      @battle.continueTurn()
      @battle.endTurn()
      @battle.beginTurn()
      @battle.requests.should.not.have.property(@id1)
      should.exist(@battle.getAction(@p1))

    it "only spends 1 PP for the entire attack", ->
      shared.create.call(this, gen: 'xy')
      move = @battle.getMove("Phantom Force")
      @p1.moves = [ move ]
      @p1.resetAllPP()

      pp = @p1.pp(move)
      @battle.recordMove(@id1, move)
      @battle.continueTurn()
      @p1.pp(move).should.equal(pp)
      @battle.beginTurn()
      @battle.continueTurn()
      @p1.pp(move).should.equal(pp - 1)

    it "skips the charge turn if the user is holding a Power Herb", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", item: "Power Herb")]
      move = @battle.getMove("Phantom Force")

      @p1.hasItem("Power Herb").should.be.true
      mock = @sandbox.mock(move).expects('execute').once()
      @battle.recordMove(@id1, move)
      @battle.continueTurn()
      mock.verify()
      @p1.hasItem().should.be.false

    it "makes target invulnerable to moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", evs: {speed: 4})]
      move = @battle.getMove("Phantom Force")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id1, move)
      @battle.recordMove(@id2, tackle)

      mock = @sandbox.mock(tackle).expects('hit').never()
      @battle.continueTurn()
      mock.verify()

    it "makes target invulnerable to moves *after* use", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", evs: {speed: 4})]
      move = @battle.getMove("Phantom Force")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id1, move)
      @battle.recordMove(@id2, tackle)

      mock = @sandbox.mock(tackle).expects('hit').once()
      @battle.continueTurn()
      mock.verify()

    it "is vulnerable to attacks from a No Guard pokemon", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "No Guard")]
      move = @battle.getMove("Phantom Force")
      tackle = @battle.getMove("Tackle")

      @battle.recordMove(@id1, move)
      @battle.recordMove(@id2, tackle)

      mock = @sandbox.mock(tackle).expects('hit').once()
      @battle.continueTurn()
      mock.verify()

    it "is vulnerable to attacks if locked on"

  describe "Toxic", ->
    it "has perfect accuracy from a Poison type pokemon", ->
      shared.create.call(this, gen: 'xy')
      @p1.types = [ "Poison" ]
      @p2.types = [ "Normal" ]
      toxic = @battle.getMove("Toxic")
      toxic.chanceToHit(@battle, @p1, @p2).should.equal(0)

  describe "Parting Shot", ->
    it "reduces the attack and special attack of the target by two stages", ->
      shared.create.call(this, gen: 'xy')
      @battle.performMove(@p1, @battle.getMove("Parting Shot"))
      @p2.stages.should.include attack: -1, specialAttack: -1

    it "forces the owner to switch", ->
      shared.create.call(this, gen: 'xy')
      @battle.performMove(@p1, @battle.getMove("Parting Shot"))
      @battle.requests.should.have.property @id1

  describe "Worry Seed", ->
    it "does not change some abilities", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Smeargle")]
        team2: [Factory("Aegislash", ability: "Stance Change")]
      worrySeed = @battle.getMove("Worry Seed")
      mock = @sandbox.mock(worrySeed).expects('fail').once()
      @battle.performMove(@p1, worrySeed)
      mock.verify()

  describe "Simple Beam", ->
    it "does not change some abilities", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Smeargle")]
        team2: [Factory("Aegislash", ability: "Stance Change")]
      simpleBeam = @battle.getMove("Simple Beam")
      mock = @sandbox.mock(simpleBeam).expects('fail').once()
      @battle.performMove(@p1, simpleBeam)
      mock.verify()

  testTrappingMove = (name) ->
    describe name, ->
      it "deals 1/8 of the pokemon's max hp every turn", ->
        shared.create.call this,
          gen: 'xy'
          team2: [Factory("Blissey")]
        @battle.performMove(@p1, @battle.getMove(name))
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        maxHP = @p2.stat('hp')
        expected = maxHP - Math.floor(maxHP / 8)
        @p2.currentHP.should.equal expected

      it "deals 1/6 of the pokemon's max hp every turn if the user is holding a Binding Band", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", item: "Binding Band")]
          team2: [Factory("Blissey")]
        @battle.performMove(@p1, @battle.getMove(name))
        @p2.currentHP = @p2.stat('hp')
        @battle.endTurn()
        maxHP = @p2.stat('hp')
        expected = maxHP - Math.floor(maxHP / 6)
        @p2.currentHP.should.equal expected

  testTrappingMove "Bind"
  testTrappingMove "Clamp"
  testTrappingMove "Fire Spin"
  testTrappingMove "Infestation"
  testTrappingMove "Magma Storm"
  testTrappingMove "Sand Tomb"
  testTrappingMove "Wrap"

  describe "Entrainment", ->
    it "does not change some abilities", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Swift Swim")]
        team2: [Factory("Aegislash", ability: "Stance Change")]
      entrainment = @battle.getMove("Entrainment")
      mock = @sandbox.mock(entrainment).expects('fail').once()
      @battle.performMove(@p1, entrainment)
      mock.verify()

  describe "Nature Power", ->
    it "uses Tri Attack in Wi-Fi battles", ->
      shared.create.call(this, gen: 'xy')
      naturePower = @battle.getMove('Nature Power')
      triAttack = @battle.getMove('Tri Attack')

      mock = @sandbox.mock(triAttack).expects('execute').once()
                                      .withArgs(@battle, @p1, [ @p2 ])
      @battle.performMove(@p1, naturePower)
      mock.verify()
