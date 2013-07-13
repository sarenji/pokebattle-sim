{Attachment, Battle, Pokemon, Status, Weather} = require('../../').server
util = require '../../server/util'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'

require '../helpers'
require 'sugar'

describe "BW Abilities:", ->
  describe "Adaptability", ->
    it "makes STAB 2x instead of 1.5", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Adaptability")]
      hydroPump = @battle.getMove("Hydro Pump")
      hydroPump.stabModifier(@battle, @p1, @p2).should.equal(0x2000)

    it "still has 1x if the pokemon does not have STAB", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Adaptability")]
      tackle = @battle.getMove("Tackle")
      tackle.stabModifier(@battle, @p1, @p2).should.equal(0x1000)

  describe "Aftermath", ->
    it "deals 25% HP damage to the killer", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Aftermath")]
      @p1.currentHP = 1
      @battle.performMove(@id2, @battle.getMove("Tackle"))
      (@p2.stat('hp') - @p2.currentHP).should.equal(@p2.stat('hp') >> 2)

    it "does not deal damage for non-contact moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Aftermath")]
      @p1.currentHP = 1
      @battle.performMove(@id2, @battle.getMove("Thunderbolt"))
      @p2.currentHP.should.equal(@p2.stat('hp'))

    # TODO: When can a Pokemon faint??
    it "does not deal damage if pokemon died of natural causes", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Aftermath")]
      @battle.performMove(@id2, @battle.getMove("Thunderbolt"))
      @p1.faint()
      @battle.endTurn()
      @p2.currentHP.should.equal(@p2.stat('hp'))

  testWeatherPreventionAbility = (name) ->
    describe name, ->
      it "causes the battle to think there is no weather", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @battle.setWeather(Weather.SAND)
        @battle.hasWeather(Weather.SAND).should.be.false
        @battle.setWeather(Weather.SUN)
        @battle.hasWeather(Weather.SUN).should.be.false

  testWeatherPreventionAbility("Air Lock")
  testWeatherPreventionAbility("Cloud Nine")

  describe "Analytic", ->
    it "multiplies attacks by 1.3 if no one is moving afterward", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Analytic")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)

    it "doesn't multiply if the user isn't the last to move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Analytic")]
      tackle = @battle.getMove("Tackle")
      @battle.recordMove(@id2, tackle)
      @battle.determineTurnOrder()
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Anger Point", ->
    it "maximizes Attack on critical hit", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Anger Point")]
      tackle = @battle.getMove("Tackle")
      @sandbox.stub(tackle, 'isCriticalHit', -> true)
      @p1.stages.attack.should.equal(0)
      @battle.performMove(@id2, tackle)
      @p1.stages.should.include(attack: 6)

    it "doesn't maximize attack on non-critical hits", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Anger Point")]
      tackle = @battle.getMove("Tackle")
      @sandbox.stub(tackle, 'isCriticalHit', -> false)
      @p1.stages.attack.should.equal(0)
      @battle.performMove(@id2, tackle)
      @p1.stages.should.include(attack: 0)

  describe "Anticipation", ->
    it "shows a message if an opponent has a super-effective move", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]
        team2: [Factory("Pikachu", moves: ["Thunderbolt"])]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@id1, 1)
      spy.calledWithMatch('shuddered').should.be.true

    it "shows a message if an opponent has an OHKO move", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]
        team2: [Factory("Lapras", moves: ["Sheer Cold"])]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@id1, 1)
      spy.calledWithMatch('shuddered').should.be.true

    it "doesn't show a message otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@id1, 1)
      spy.calledWithMatch('shuddered').should.be.false

   describe "Arena Trap", ->
    it "blocks switch", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Arena Trap")]
        team2: [Factory("Magikarp")]
      @p2.isSwitchBlocked().should.be.true

    it "blocks switch the next turn as well", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Arena Trap")]
        team2: [Factory("Magikarp")]
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.true

    it "doesn't block switch for Flying Pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Arena Trap")]
        team2: [Factory("Gyarados")]
      @p2.isSwitchBlocked().should.be.false

    it "doesn't block switch for Pokemon immune to Ground by other means", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Arena Trap")]
        team2: [Factory("Magikarp")]
      @battle.performMove(@id2, @battle.getMove("Magnet Rise"))
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.false

  describe "Bad Dreams", ->
    it "deals 1/8 max HP end of turn if target is asleep", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Bad Dreams")]
        team2: [Factory("Celebi")]
      (@p2.stat('hp') - @p2.currentHP).should.equal(0)
      @p2.setStatus(Status.SLEEP)
      @battle.endTurn()
      (@p2.stat('hp') - @p2.currentHP).should.equal(@p2.stat('hp') >> 3)

    it "deals no damage if target is awake", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Bad Dreams")]
        team2: [Factory("Celebi")]
      (@p2.stat('hp') - @p2.currentHP).should.equal(0)
      @battle.endTurn()
      (@p2.stat('hp') - @p2.currentHP).should.equal(0)

  testCriticalHitPreventionAbility = (name) ->
    describe name, ->
      it "prevents critical hits", ->
        shared.create.call this,
          team1: [Factory("Magikarp")]
          team2: [Factory("Celebi", ability: name)]
        shared.biasRNG.call(this, "next", "ch", .2)
        tackle = @battle.getMove("Tackle")
        @sandbox.stub(tackle, 'criticalHitLevel', -> 3)
        tackle.isCriticalHit(@battle, @p1, @p2).should.be.false

  testCriticalHitPreventionAbility("Battle Armor")
  testCriticalHitPreventionAbility("Shell Armor")

  testBoostProtectionAbility = (name, protection) ->
    describe name, ->
      allBoosts = [ "attack", "defense", "speed", "specialAttack",
                    "specialDefense", "accuracy", "evasion" ]
      protection ||= allBoosts
      for stat in protection
        do (stat) ->
          it "protects against #{stat} falls"
      if protection.length < allBoosts.length
        it "doesn't protect against other stat falls"

  testBoostProtectionAbility("Big Pecks", [ "defense" ])
  testBoostProtectionAbility("Clear Body")
  testBoostProtectionAbility("Hyper Cutter", [ "attack" ])
  testBoostProtectionAbility("Keen Eye", [ "accuracy" ])

  testLowHealthAbility = (name, type) ->
    describe name, ->
      it "increases power of #{type} moves by 1.5 at 1/3 health", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3)
        move = @battle.getMoveList().find (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

      it "doesn't increase power if move not of #{type}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3)
        move = @battle.getMoveList().find (m) ->
          m.type != type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

      it "doesn't increase power if user isn't under 1/3 health", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3) + 1
        move = @battle.getMoveList().find (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  testLowHealthAbility("Blaze", "Fire")
  testLowHealthAbility("Torrent", "Water")
  testLowHealthAbility("Overgrow", "Grass")
  testLowHealthAbility("Swarm", "Bug")

  testWeatherSpeedAbility = (name, weather) ->
    describe name, ->
      it "doubles speed when the weather becomes #{weather}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        speed = @p1.stat('speed')
        @battle.setWeather(weather)
        @p1.stat('speed').should.equal(2 * speed)

      it "goes back to normal when the weather becomes something else", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        speed = @p1.stat('speed')
        @battle.setWeather(weather)
        @battle.setWeather(Weather.NONE)
        @p1.stat('speed').should.equal(speed)

  testWeatherSpeedAbility("Chlorophyll", Weather.SUN)
  testWeatherSpeedAbility("Swift Swim", Weather.RAIN)
  testWeatherSpeedAbility("Sand Rush", Weather.SAND)

  describe "Color Change", ->
    it "changes the owner's type to be the move's type that just hit it", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Color Change")]
      ember = @battle.getMove("Ember")
      @p1.hasType(ember.type).should.be.false
      @battle.performMove(@id2, ember)
      @p1.hasType(ember.type).should.be.true

    it "does not change the owner's type if the move is non-damaging", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Color Change")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      @p1.hasType(willOWisp.type).should.be.false
      @battle.performMove(@id2, willOWisp)
      @p1.hasType(willOWisp.type).should.be.false

  describe "Compoundeyes", ->
    it "increases accuracy of moves by 1.3x", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Compoundeyes")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      accuracy = willOWisp.chanceToHit(@battle, @p1, @p2)
      accuracy.should.equal Math.floor(willOWisp.accuracy * 1.3)

  describe "Contrary", ->
    it "reverses stat changes from all sources", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Contrary")]
      leafStorm = @battle.getMove("Leaf Storm")
      growl     = @battle.getMove("Growl")
      @battle.performMove(@id1, leafStorm)
      @p1.stages.should.include(specialAttack: 2)
      @battle.performMove(@id2, growl)
      @p1.stages.should.include(attack: 1)

  describe "Cursed Body", ->
    it "has a 30% chance to disable an attacker's last move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", 0)
      tackle = @battle.getMove("Tackle")
      @p2.moves = [ tackle ]
      @battle.performMove(@id2, tackle)
      @p2.isMoveBlocked(tackle).should.be.true

    it "does not disable if behind a substitute", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", 0)
      tackle = @battle.getMove("Tackle")
      substitute = @battle.getMove("Substitute")
      @p2.moves = [ tackle ]
      @battle.performMove(@id2, substitute)
      @battle.performMove(@id2, tackle)
      @p2.isMoveBlocked(tackle).should.be.false

    it "has a 70% chance to do nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", .3)
      tackle = @battle.getMove("Tackle")
      @p2.moves = [ tackle ]
      @battle.performMove(@id2, tackle)
      @p2.isMoveBlocked(tackle).should.be.false

  describe "Cute Charm", ->
    it "has a 30% chance to attract the attacker", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cute Charm")]
      shared.biasRNG.call(this, "next", "cute charm", 0)
      @battle.performMove(@id2, @battle.getMove("Tackle"))
      @p2.has(Attachment.Attract).should.be.true

    it "does not attract if the move is not a contact move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cute Charm")]
      shared.biasRNG.call(this, "next", "cute charm", 0)
      @battle.performMove(@id2, @battle.getMove("Thunderbolt"))
      @p2.has(Attachment.Attract).should.be.false

    it "has a 70% chance to do nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cute Charm")]
      shared.biasRNG.call(this, "next", "cute charm", .3)
      @battle.performMove(@id2, @battle.getMove("Tackle"))
      @p2.has(Attachment.Attract).should.be.false
