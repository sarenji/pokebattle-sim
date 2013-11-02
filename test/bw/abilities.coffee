{Attachment, Status} = require('../../server/bw/attachment')
{Battle} = require('../../server/bw/battle')
{Pokemon} = require('../../server/bw/pokemon')
{Weather} = require('../../server/bw/weather')
{Ability} = require '../../server/bw/data/abilities'
util = require '../../server/bw/util'
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
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @battle.performFaints()
      (@p2.stat('hp') - @p2.currentHP).should.equal(@p2.stat('hp') >> 2)

    it "does not deal damage for non-contact moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Aftermath")]
      @p1.currentHP = 1
      @battle.performMove(@p2, @battle.getMove("Thunderbolt"))
      @battle.performFaints()
      @p2.currentHP.should.equal(@p2.stat('hp'))

    it "does not deal damage if pokemon died of natural causes", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Aftermath")]
      thunderbolt = @battle.getMove("Thunderbolt")
      @p1.currentHP = 2
      @p1.attach(Status.Burn)
      @sandbox.stub(thunderbolt, 'calculateDamage', -> 1)
      @battle.performMove(@p2, thunderbolt)
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
      @battle.performMove(@p2, tackle)
      @p1.stages.should.include(attack: 6)

    it "doesn't maximize attack on non-critical hits", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Anger Point")]
      tackle = @battle.getMove("Tackle")
      @sandbox.stub(tackle, 'isCriticalHit', -> false)
      @p1.stages.attack.should.equal(0)
      @battle.performMove(@p2, tackle)
      @p1.stages.should.include(attack: 0)

  describe "Anticipation", ->
    it "shows a message if an opponent has a super-effective move", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]
        team2: [Factory("Pikachu", moves: ["Thunderbolt"])]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@p1, 1)
      spy.calledWithMatch('shuddered').should.be.true

    it "shows a message if an opponent has an OHKO move", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]
        team2: [Factory("Lapras", moves: ["Sheer Cold"])]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@p1, 1)
      spy.calledWithMatch('shuddered').should.be.true

    it "doesn't show a message otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Anticipation")]

      spy = @sandbox.spy(@battle, 'message')
      @battle.performSwitch(@p1, 1)
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
      @battle.performMove(@p2, @battle.getMove("Magnet Rise"))
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.false

  describe "Bad Dreams", ->
    it "deals 1/8 max HP end of turn if target is asleep", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Bad Dreams")]
        team2: [Factory("Celebi")]
      (@p2.stat('hp') - @p2.currentHP).should.equal(0)
      @p2.attach(Status.Sleep)
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

      it "protects against certain stat falls", ->
        shared.create.call this, team1: [Factory("Celebi", ability: name)]
        boosts = {}
        boosts[stat] = -1  for stat in allBoosts
        @p1.boost(boosts, @p2)
        boosts[stat] = 0  for stat in protection
        @p1.stages.should.eql(boosts)

      it "does not protect against stat falls if the source is the user", ->
        shared.create.call this, team1: [Factory("Celebi", ability: name)]
        boosts = {}
        boosts[stat] = -1  for stat in allBoosts
        @p1.boost(boosts)
        @p1.stages.should.include(boosts)

  testBoostProtectionAbility("Big Pecks", [ "defense" ])
  testBoostProtectionAbility("Clear Body")
  testBoostProtectionAbility("Hyper Cutter", [ "attack" ])
  testBoostProtectionAbility("Keen Eye", [ "accuracy" ])
  testBoostProtectionAbility("White Smoke")

  testLowHealthAbility = (name, type) ->
    describe name, ->
      it "increases power of #{type} moves by 1.5 at 1/3 health", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3)
        move = @battle.MoveList.find (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

      it "doesn't increase power if move not of #{type}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3)
        move = @battle.MoveList.find (m) ->
          m.type != type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

      it "doesn't increase power if user isn't under 1/3 health", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.currentHP = Math.floor(@p1.stat('hp') / 3) + 1
        move = @battle.MoveList.find (m) ->
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

      it "grants immunity to damage from their respective weather", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        @p1.isWeatherDamageImmune(weather).should.be.true

  testWeatherSpeedAbility("Chlorophyll", Weather.SUN)
  testWeatherSpeedAbility("Swift Swim", Weather.RAIN)
  testWeatherSpeedAbility("Sand Rush", Weather.SAND)

  describe "Color Change", ->
    it "changes the owner's type to be the move's type that just hit it", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Color Change")]
      ember = @battle.getMove("Ember")
      @p1.hasType(ember.type).should.be.false
      @battle.performMove(@p2, ember)
      @p1.hasType(ember.type).should.be.true

    it "does not change the owner's type if the move is non-damaging", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Color Change")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      @p1.hasType(willOWisp.type).should.be.false
      @battle.performMove(@p2, willOWisp)
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
      @battle.performMove(@p1, leafStorm)
      @p1.stages.should.include(specialAttack: 2)
      @battle.performMove(@p2, growl)
      @p1.stages.should.include(attack: 1)

  describe "Cursed Body", ->
    it "has a 30% chance to disable an attacker's last move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", 0)
      tackle = @battle.getMove("Tackle")
      @p2.moves = [ tackle ]
      @battle.performMove(@p2, tackle)
      @p2.isMoveBlocked(tackle).should.be.true

    it "does not disable if behind a substitute", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", 0)
      tackle = @battle.getMove("Tackle")
      substitute = @battle.getMove("Substitute")
      @p2.moves = [ tackle ]
      @battle.performMove(@p2, substitute)
      @battle.performMove(@p2, tackle)
      @p2.isMoveBlocked(tackle).should.be.false

    it "has a 70% chance to do nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Cursed Body")]
      shared.biasRNG.call(this, "next", "cursed body", .3)
      tackle = @battle.getMove("Tackle")
      @p2.moves = [ tackle ]
      @battle.performMove(@p2, tackle)
      @p2.isMoveBlocked(tackle).should.be.false

  describe "Defeatist", ->
    it "halves attack and special attack if HP goes under 50%", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Defeatist")]
      tackle = @battle.getMove("Tackle")
      thunderbolt = @battle.getMove("Thunderbolt")

      # 50%
      @p1.currentHP = (@p1.stat('hp') >> 1)
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x800)
      thunderbolt.modifyAttack(@battle, @p1, @p2).should.equal(0x800)

      # 50% + 1
      @p1.currentHP = (@p1.stat('hp') >> 1) + 1
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      thunderbolt.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)

  describe "Defiant", ->
    it "boosts attack by 2 every time a stat is lowered"
    it "does not boost attack if the stat was self-lowered"

  describe "Download", ->
    it "raises attack if foes have total defense < total sp.def", ->
      shared.create.call this,
        team1: [Factory("Magikarp")]
        team2: [Factory("Abomasnow")]
      @p1.stages.should.include(attack: 0)
      @p1.copyAbility(Ability.Download)
      @p1.stages.should.include(attack: 1)

    it "raises special attack if foes have total sp.def <= total def", ->
      shared.create.call this,
        team1: [Factory("Magikarp")]
        team2: [Factory("Celebi")]
      @p1.stages.should.include(specialAttack: 0)
      @p1.copyAbility(Ability.Download)
      @p1.stages.should.include(specialAttack: 1)

  testWeatherAbility = (name, weather) ->
    describe name, ->
      it "causes unending #{weather}", ->
        shared.build(this, team1: [Factory("Magikarp", ability: name)])
        @battle.hasWeather().should.be.false
        @controller.beginBattle()
        @battle.hasWeather(weather).should.be.true
        @battle.weatherDuration.should.equal(-1)

  testWeatherAbility("Drizzle", Weather.RAIN)
  testWeatherAbility("Drought", Weather.SUN)
  testWeatherAbility("Sand Stream", Weather.SAND)
  testWeatherAbility("Snow Warning", Weather.HAIL)

  describe "Dry Skin", ->
    it "gets healed 25% HP by water moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Dry Skin")])
      @p1.currentHP = 1
      @battle.performMove(@p2, @battle.getMove("Hydro Pump"))
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 2))
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.currentHP.should.be.lessThan(1 + (@p1.stat('hp') >> 2))

    it "gets healed 1/8 HP end of turn in Rain", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Dry Skin")])
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1)
      @battle.setWeather(Weather.RAIN)
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 3))

    it "gets damaged 25% extra by fire moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Dry Skin")])
      ember = @battle.getMove("Ember")
      ember.modifyBasePower(@battle, @p2, @p1).should.equal(0x1400)
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p2, @p1).should.equal(0x1000)

    it "gets hurt 1/8 HP end of turn in Sun", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Dry Skin")])
      @battle.endTurn()
      @p1.currentHP.should.equal(@p1.stat('hp'))
      @battle.setWeather(Weather.SUN)
      @battle.endTurn()
      (@p1.stat('hp') - @p1.currentHP).should.equal(@p1.stat('hp') >> 3)

  describe "Early Bird", ->
    it "halves sleep turns", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Early Bird")])
      shared.biasRNG.call(this, "randInt", 'sleep turns', 1)
      @p1.attach(Status.Sleep)
      @battle.performMove(@p1, @battle.getMove('Tackle'))
      @p1.has(Status.Sleep).should.be.false

  describe "Effect Spore", ->
    it "has a 30% chance to inflict poison, paralysis, or sleep on hit", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Effect Spore")])

      # Sleep
      shared.biasRNG.call(this, "randInt", 'effect spore', 1)
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @p2.has(Status.Sleep).should.be.true

      # Paralysis
      @p2.cureStatus()
      shared.biasRNG.call(this, "randInt", 'effect spore', 2)
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @p2.has(Status.Paralyze).should.be.true

      # Poison
      @p2.cureStatus()
      shared.biasRNG.call(this, "randInt", 'effect spore', 3)
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @p2.has(Status.Poison).should.be.true

    it "has a 70% chance to do nothing", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Effect Spore")])
      shared.biasRNG.call(this, "randInt", 'effect spore', 4)
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @p2.hasStatus().should.be.false

    it "doesn't trigger if the hitting move is a non-contact move", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Effect Spore")])
      shared.biasRNG.call(this, "randInt", 'effect spore', 1)
      @battle.performMove(@p2, @battle.getMove('Thunderbolt'))
      @p2.has(Status.Sleep).should.be.false

  testFilterAbility = (name) ->
    describe name, ->
      it "reduces the impact of super-effective moves by 25%", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        seMove = @battle.MoveList.find (m) =>
          !m.isNonDamaging() && util.typeEffectiveness(m.type, @p1.types) > 1
        seMove.modifyDamage(@battle, @p2, @p1).should.equal(0xC00)

      it "keeps non-super-effective moves as normal", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        seMove = @battle.MoveList.find (m) =>
          !m.isNonDamaging() && util.typeEffectiveness(m.type, @p1.types) <= 1
        seMove.modifyDamage(@battle, @p2, @p1).should.equal(0x1000)

  testFilterAbility("Filter")
  testFilterAbility("Solid Rock")

  testContactStatusAbility = (name, attachment) ->
    describe name, ->
      it "has a 30% chance to inflict #{attachment.name} on the attacker", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        shared.biasRNG.call(this, "next", 'contact status', 0)
        @battle.performMove(@p2, @battle.getMove('Tackle'))
        @p2.has(attachment).should.be.true

      it "inflicts no status if the move used is a non-contact move", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        shared.biasRNG.call(this, "next", 'contact status', 0)
        @battle.performMove(@p2, @battle.getMove('Thunderbolt'))
        @p2.has(attachment).should.be.false

      it "has a 70% chance to do nothing", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        shared.biasRNG.call(this, "next", 'contact status', .3)
        @battle.performMove(@p2, @battle.getMove('Tackle'))
        @p2.has(attachment).should.be.false

  testContactStatusAbility("Cute Charm", Attachment.Attract)
  testContactStatusAbility("Flame Body", Status.Burn)
  testContactStatusAbility("Poison Point", Status.Poison)
  testContactStatusAbility("Static", Status.Paralyze)

  testStatusBoostAbility = (name, statuses, spectra) ->
    statusNames = statuses.map((s) -> s.name).join(', ')
    describe name, ->
      it "increases #{spectra} moves by 1.5 if has #{statusNames}", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        move = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.spectra == spectra

        for status in statuses
          @p1.cureStatus()
          @p1.attach(status)
          move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

      it "does not increase non-#{spectra} moves", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        move = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.spectra != spectra

        for status in statuses
          @p1.cureStatus()
          @p1.attach(status)
          move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  testStatusBoostAbility("Flare Boost", [Status.Burn], "special")
  testStatusBoostAbility("Toxic Boost", [Status.Poison, Status.Toxic], "physical")

  describe "Flash Fire", ->
    it "makes user invulnerable to Fire-type moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Flash Fire")])
      ember = @battle.getMove("Ember")
      mock  = @sandbox.mock(ember).expects('hit').never()
      @battle.performMove(@p2, ember)
      mock.verify()

    it "powers up user's Fire-type moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Flash Fire")])
      ember = @battle.getMove("Ember")
      tackle = @battle.getMove("Tackle")
      @battle.performMove(@p2, ember)
      ember.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Flower Gift", ->
    it "changes Cherrim's forme"
    it "does not change a transformed pokemon's forme"
    it "grants x1.5 attack and special defense in Sun"
    it "grants x1.5 attack and special defense to allies in Sun"

  describe "Forecast", ->
    it "changes Castform's forme"
    it "does not change a transformed pokemon's forme"

  describe "Forewarn", ->
    it "considers OHKO moves to have 160 BP", ->
      shared.create.call(this)
      Ability.Forewarn.consider(@battle.getMove("Fissure")).should.equal(160)

    it "considers counter moves to have 120 BP", ->
      shared.create.call(this)
      {consider} = Ability.Forewarn
      consider(@battle.getMove("Counter")).should.equal(120)
      consider(@battle.getMove("Mirror Coat")).should.equal(120)
      consider(@battle.getMove("Metal Burst")).should.equal(120)

    it "considers specific variable power moves to have 80 BP", ->
      shared.create.call(this)
      {consider} = Ability.Forewarn
      consider(@battle.getMove("Crush Grip")).should.equal(80)
      consider(@battle.getMove("Dragon Rage")).should.equal(80)
      consider(@battle.getMove("Endeavor")).should.equal(80)
      consider(@battle.getMove("Flail")).should.equal(80)
      consider(@battle.getMove("Frustration")).should.equal(80)
      consider(@battle.getMove("Grass Knot")).should.equal(80)
      consider(@battle.getMove("Gyro Ball")).should.equal(80)
      consider(@battle.getMove("Hidden Power")).should.equal(80)
      consider(@battle.getMove("Low Kick")).should.equal(80)
      consider(@battle.getMove("Natural Gift")).should.equal(80)
      consider(@battle.getMove("Night Shade")).should.equal(80)
      consider(@battle.getMove("Psywave")).should.equal(80)
      consider(@battle.getMove("Return")).should.equal(80)
      consider(@battle.getMove("Reversal")).should.equal(80)
      consider(@battle.getMove("Seismic Toss")).should.equal(80)
      consider(@battle.getMove("SonicBoom")).should.equal(80)
      consider(@battle.getMove("Trump Card")).should.equal(80)
      consider(@battle.getMove("Wring Out")).should.equal(80)

    it "alerts user about a foe's move with the highest base power", ->
      shared.build(this, team1: [Factory("Magikarp", ability: "Forewarn")])
      spy = @sandbox.spy(@battle, 'message')
      @controller.beginBattle()
      spy.calledWithMatch('Tackle').should.be.true

  describe "Friend Guard", ->
    it "weakens attacks from allies by 25%", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Friend Guard")]
      earthquake = @battle.getMove("Earthquake")
      earthquake.modifyDamage(@battle, @p1, @team1.at(1)).should.equal(0xC00)

    it "keeps attacks by enemies at normal", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Friend Guard")]
      earthquake = @battle.getMove("Earthquake")
      earthquake.modifyDamage(@battle, @p2, @team1.at(1)).should.equal(0x1000)

  describe "Frisk", ->
    it "randomly selects an opponent and displays the item", ->
      shared.build this,
        team1: [Factory("Magikarp", ability: "Frisk")]
        team2: [Factory("Magikarp", item: "Leftovers")]
      spy = @sandbox.spy(@battle, 'message')
      @controller.beginBattle()
      spy.calledWithMatch('Leftovers').should.be.true

  describe "Gluttony", ->
    it "makes berries activate at 50% HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Gluttony")]
      @p1.stages.should.include(speed: 0)
      @p1.currentHP >>= 1
      @p1.update()
      @p1.stages.should.include(speed: 1)

  describe "Guts", ->
    it "multiplies attack by x1.5 if statused", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Guts")])
      tackle = @battle.getMove("Tackle")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      @p1.attach(Status.Burn)
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1800)

    it "does not multiply attack if move is special", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Guts")])
      thunderbolt = @battle.getMove("Thunderbolt")
      @p1.attach(Status.Burn)
      thunderbolt.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)

  describe "Harvest", ->
    it "has a 50% chance of re-obtaining a berry it used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Harvest")]
      shared.biasRNG.call(this, "randInt", "harvest", 1)
      @p1.useItem()
      @battle.endTurn()
      @p1.hasItem("Salac Berry").should.be.true

    it "has a 50% chance of doing nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Harvest")]
      shared.biasRNG.call(this, "randInt", "harvest", 0)
      @p1.useItem()
      @battle.endTurn()
      @p1.hasItem("Salac Berry").should.be.false

    it "has a 100% chance to re-obtain the berry in Sun", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Harvest")]
      shared.biasRNG.call(this, "randInt", "harvest", 0)
      @p1.useItem()
      @battle.setWeather(Weather.SUN)
      @battle.endTurn()
      @p1.hasItem("Salac Berry").should.be.true

    it "does not regain a normal item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flying Gem", ability: "Harvest")]
      shared.biasRNG.call(this, "randInt", "harvest", 1)
      @p1.useItem()
      @battle.endTurn()
      @p1.hasItem("Flying Gem").should.be.false

    it "does not regain the berry if it was removed", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Harvest")]
      shared.biasRNG.call(this, "randInt", "harvest", 1)
      @p1.removeItem()
      @battle.endTurn()
      @p1.hasItem("Flying Gem").should.be.false

  describe "Healer", ->
    it "has a 30% chance of healing an adjacent ally's status", ->
      shared.create.call this,
        numActive: 3
        team1: [Factory("Magikarp", ability: "Healer"), Factory("Magikarp"), Factory("Magikarp")]
      shared.biasRNG.call(this, "randInt", "healer", 3)
      @team1.at(0).attach(Status.Burn)
      @team1.at(1).attach(Status.Burn)
      @team1.at(2).attach(Status.Burn)
      @battle.endTurn()
      @team1.at(0).hasStatus().should.be.true
      @team1.at(1).hasStatus().should.be.false
      @team1.at(2).hasStatus().should.be.true

    it "has a 70% chance to do nothing", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Healer")]
      shared.biasRNG.call(this, "randInt", "healer", 4)
      @p1.attach(Status.Burn)
      @battle.endTurn()
      @p1.hasStatus().should.be.true

  describe "Heatproof", ->
    it "receives half damage from Fire-type moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Heatproof")])
      ember = @battle.getMove("Ember")
      ember.modifyBasePower(@battle, @p2, @p1).should.equal(0x800)

    it "receives normal damage from non-Fire-type moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Heatproof")])
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p2, @p1).should.equal(0x1000)

    it "receives half damage from burn", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Heatproof")])
      @p1.attach(Status.Burn)
      burn = @p1.get(Status.Burn)
      mock = @sandbox.mock(burn).expects('endTurn').returns(@p1.currentHP >> 4)
      @battle.endTurn()
      mock.verify()

  describe "Heavy Metal", ->
    it "doubles the user's weight", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Heavy Metal")])
      @p1.calculateWeight().should.equal(2 * @p1.weight)

  testHugePowerAbility = (name) ->
    describe name, ->
      it "doubles attack when using a physical move", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        tackle = @battle.getMove("Tackle")
        tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x2000)

      it "does not double attack when using a special move", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        thunderbolt = @battle.getMove("Thunderbolt")
        thunderbolt.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)

  testHugePowerAbility("Huge Power")
  testHugePowerAbility("Pure Power")

  describe "Hustle", ->
    it "multiplies attack by x1.5", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Hustle")])
      tackle = @battle.getMove("Tackle")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1800)
      thunderbolt = @battle.getMove("Thunderbolt")
      thunderbolt.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)

    it "makes physical moves have 20% less accuracy", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Hustle")])
      tackle = @battle.getMove("Tackle")
      accuracy = tackle.chanceToHit(@battle, @p1, @p2)
      accuracy.should.equal Math.floor(tackle.accuracy * 0.8)

      thunderbolt = @battle.getMove("Thunderbolt")
      accuracy = thunderbolt.chanceToHit(@battle, @p1, @p2)
      accuracy.should.equal Math.floor(thunderbolt.accuracy * 1.0)

  describe "Hydration", ->
    it "restores status, in Rain, at the end of the turn", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Hydration")])
      @p1.attach(Status.Sleep)
      @battle.setWeather(Weather.RAIN)
      @battle.endTurn()
      @p1.hasStatus().should.be.false

    it "does not restore status if the weather is not rainy", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Hydration")])
      @p1.attach(Status.Sleep)
      @battle.endTurn()
      @p1.hasStatus().should.be.true

  describe "Ice Body", ->
    it "restores 1/16 HP in Hail", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Ice Body")]
      @p1.currentHP = 1
      @battle.setWeather(Weather.HAIL)
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 4))

    it "restores no HP in other weather", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Ice Body")]
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1)

    it "grants immunity to Hail", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Ice Body")]
      @p1.isWeatherDamageImmune(Weather.HAIL).should.be.true

  describe "Illusion", ->
    it "masquerades as the last unfainted pokemon in player's party"
    it "does not masquerade if all pokemon are fainted"
    it "is broken when the user takes direct damage"

  describe "Imposter", ->
    it "automatically transforms into the adjacent foe pokemon", ->
      shared.create.call this,
        numActive: 2
        team1: (Factory("Magikarp")  for x in [1..2])
        team2: [Factory("Celebi"), Factory("Mew")]
      @team1.at(1).copyAbility(Ability.Imposter)
      @team1.at(1).has(Attachment.Transform).should.be.true
      @team1.at(1).species.should.equal @team2.at(1).species

    it "does not transform if target is behind a substitute", ->
      shared.create.call(this)
      @p2.attach(Attachment.Substitute, hp: 1)
      @p1.copyAbility(Ability.Imposter)
      @p1.has(Attachment.Transform).should.be.false

    it "does not transform if target is already transformed", ->
      shared.create.call(this)
      @battle.performMove(@p2, @battle.getMove("Transform"))
      @p2.has(Attachment.Transform).should.be.true
      @p1.copyAbility(Ability.Imposter)
      @p1.has(Attachment.Transform).should.be.false

  testAttachmentImmuneAbility = (name, attachments) ->
    describe name, ->
      it "prevents the pokemon from receiving a specific attachment", ->
        shared.create.call this, team1: [Factory("Magikarp", ability: name)]
        for attachment in attachments
          should.not.exist @p1.attach(attachment)
          @p1.has(attachment).should.be.false

      it "removes the attachment if the pokemon already has it", ->
        shared.create.call this, team1: [Factory("Magikarp")]
        for attachment in attachments
          @p1.attach(attachment)
          @p1.has(attachment).should.be.true
          @p1.copyAbility(Ability[name.replace(/\s+/g, '')])
          @p1.update()
          @p1.has(attachment).should.be.false
          @p1.copyAbility(null)

  testAttachmentImmuneAbility("Immunity", [Status.Poison, Status.Toxic])
  testAttachmentImmuneAbility("Inner Focus", [Attachment.Flinch])
  testAttachmentImmuneAbility("Insomnia", [Status.Sleep])
  testAttachmentImmuneAbility("Limber", [Status.Paralyze])
  testAttachmentImmuneAbility("Magma Armor", [Status.Freeze])
  testAttachmentImmuneAbility("Oblivious", [Attachment.Attract])
  testAttachmentImmuneAbility("Own Tempo", [Attachment.Confusion])
  testAttachmentImmuneAbility("Vital Spirit", [Status.Sleep])
  testAttachmentImmuneAbility("Water Veil", [Status.Burn])

  describe "Intimidate", ->
    it "lowers the attack of all foe pokemon", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Intimidate")])
      @p2.stages.should.include(attack: -1)

    it "lowers attack simultaneously on all begin-turn switch-ins", ->
      shared.create.call this,
        team1: (Factory("Magikarp", ability: "Intimidate")  for x in [1..2])
        team2: (Factory("Magikarp", ability: "Intimidate")  for x in [1..2])
      @p1.stages.should.include(attack: -1)
      @p2.stages.should.include(attack: -1)
      @p1.faint()
      @p2.faint()
      @battle.requestFaintedReplacements()
      @controller.makeSwitch(@player1, 1)
      @controller.makeSwitch(@player2, 1)
      @team1.first().should.not.equal(@p1)
      @team2.first().should.not.equal(@p2)
      @team1.first().stages.should.include(attack: -1)
      @team2.first().stages.should.include(attack: -1)

  describe "Infiltrator", ->
    it "ignores Reflect"
    it "ignores Light Screen"
    it "ignores Safeguard"
    it "ignores Mist"

  testContactHurtAbility = (name) ->
    describe name, ->
      it "damages for 1/8 HP on contact moves", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        hp = @p2.stat('hp')
        @battle.performMove(@p2, @battle.getMove("Tackle"))
        (hp - @p2.currentHP).should.equal(hp >> 3)

      it "does not damage for non-contact moves", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        @battle.performMove(@p2, @battle.getMove("Thunderbolt"))
        @p2.currentHP.should.equal @p2.stat('hp')

  testContactHurtAbility("Iron Barbs")
  testContactHurtAbility("Rough Skin")

  describe "Iron Fist", ->
    it "increases base power of punching moves by approximately x1.3", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Iron Fist")])
      icePunch = @battle.getMove("Ice Punch")
      icePunch.modifyBasePower(@battle, @p1, @p2).should.equal(0x1333)

    it "does not increase base power of non-punching moves", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Iron Fist")])
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Justified", ->
    it "boosts attack by 1 after being hit by a Dark move", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Justified")])
      @p1.stages.should.include(attack: 0)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.stages.should.include(attack: 0)
      @battle.performMove(@p2, @battle.getMove("Crunch"))
      @p1.stages.should.include(attack: 1)

  describe "Klutz", ->
    it "disables user's item upon switch-in", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", item: "Leftovers", ability: "Klutz")]
      @battle.performSwitch(@p1, 1)
      @team1.first().isItemBlocked().should.be.true

    it "disables user's item in the beginning of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leftovers", ability: "Klutz")]
      @p1.isItemBlocked().should.be.true
      @battle.beginTurn()
      @p1.isItemBlocked().should.be.true

  describe "Leaf Guard", ->
    it "defends against statuses under Sun", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Leaf Guard")]
      @battle.setWeather(Weather.SUN)
      @p1.attach(Status.Burn)
      @p1.has(Status.Burn).should.be.false

    it "does not defend against statuses otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Leaf Guard")]
      @p1.attach(Status.Burn)
      @p1.has(Status.Burn).should.be.true

  describe "Levitate", ->
    it "adds a ground immunity", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Levitate")]
      @p1.isImmune('Ground').should.be.true

  describe "Light Metal", ->
    it "halves the user's weight", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Light Metal")])
      @p1.calculateWeight().should.equal(@p1.weight >> 1)

  testRedirectAndBoostAbility = (name, type) ->
    describe name, ->
      it "should redirect attacks of #{type} to user"

      it "makes user immune to #{type}", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        mock = @sandbox.mock(typedMove).expects('hit').never()
        @battle.performMove(@p2, typedMove)
        mock.verify()

      it "boosts special attack on #{type}-type moves", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        @battle.performMove(@p2, typedMove)
        @p1.stages.should.include(specialAttack: 1)

      it "does not boost special attack on #{type}-type moves if immune", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        @sandbox.stub(@p1, 'isImmune', -> true)
        @battle.performMove(@p2, typedMove)
        @p1.stages.should.include(specialAttack: 0)

      it "does nothing otherwise", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        tackle = @battle.getMove("Tackle")
        mock = @sandbox.mock(tackle).expects('hit').once()
        @battle.performMove(@p2, tackle)
        mock.verify()
        @p1.stages.should.include(specialAttack: 0)

  testRedirectAndBoostAbility("Lightningrod", "Electric")
  testRedirectAndBoostAbility("Storm Drain", "Water")

  describe "Liquid Ooze", ->
    it "causes drain attacks to damage the user as well", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Liquid Ooze")]
      @battle.performMove(@p2, @battle.getMove("Giga Drain"))
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

    it "causes Leech Seed to damage the user as well", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Liquid Ooze")]
      @battle.performMove(@p2, @battle.getMove("Leech Seed"))
      @battle.endTurn()
      @p2.currentHP.should.be.lessThan @p2.stat('hp')

  describe "Magic Bounce", ->
    it "still has the magic coat effect next turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Bounce")]
      @p1.has(Attachment.MagicCoat).should.be.true
      @battle.endTurn()
      @p1.has(Attachment.MagicCoat).should.be.false
      @p1.has(Ability.MagicBounce).should.be.true
      @battle.beginTurn()
      @p1.has(Attachment.MagicCoat).should.be.true

  describe "Magic Guard", ->
    it "takes no damage from anything that isn't a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @p1.attach(Status.Burn)
      @p1.currentHP.should.equal(@p1.stat('hp'))
      @battle.endTurn()
      @p1.currentHP.should.equal(@p1.stat('hp'))

    it "takes damage from moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from Struggle", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @battle.performMove(@p1, @battle.getMove('Struggle'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from Belly Drum", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @battle.performMove(@p1, @battle.getMove('Belly Drum'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from confusion", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      shared.biasRNG.call(this, 'next', 'confusion', 0)
      @p1.attach(Attachment.Confusion)
      @battle.performMove(@p1, @battle.getMove('Tackle'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from using Curse", ->
      shared.create.call this,
        team1: [Factory("Gengar", ability: "Magic Guard")]
      @battle.performMove(@p1, @battle.getMove('Curse'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from Substitute", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @battle.performMove(@p1, @battle.getMove('Substitute'))
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "takes damage from Pain Split", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @p1.currentHP = 1
      @battle.performMove(@p1, @battle.getMove('Pain Split'))
      @p1.currentHP.should.be.greaterThan(1)

    it "takes damage from Counter", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard", moves: ["Counter"])]
      @controller.makeMove(@player1, "Counter")
      @controller.makeMove(@player2, "Tackle")
      @p1.currentHP.should.be.lessThan(@p1.stat('hp'))

    it "restores health from Leftovers", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard", item: "Leftovers")]
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.be.greaterThan(1)

    it "receives no damage from Rocky Helmet", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magic Guard")]
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1)

  describe "Magnet Pull", ->
    it "prevents Steel-type Pokemon from switching", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magnet Pull")]
        team2: [Factory("Magnemite")]
      @p2.isSwitchBlocked().should.be.true
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.true

    it "doesn't prevent non-Steel-type Pokemon from switching", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Magnet Pull")]
        team2: [Factory("Magikarp")]
      @p2.isSwitchBlocked().should.be.false
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.false

  describe "Marvel Scale", ->
    it "multiplies defense by 1.5 when statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Marvel Scale")]
      defense = @p1.stat('defense')
      @p1.attach(Status.Burn)
      @p1.stat('defense').should.equal Math.floor(1.5 * defense)

  describe "Minus", ->
    it "multiplies special attack by 1.5 if on the field with Plus", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp")]
        team2: [Factory("Magikarp"), Factory("Magikarp")]
      specialAttack = @p1.stat('specialAttack')
      @team1.at(0).copyAbility(Ability.Minus)
      @team1.at(1).copyAbility(Ability.Plus)
      thunderbolt = @battle.getMove("Thunderbolt")
      thunderbolt.modifyAttack(@battle, @team1.at(0), @p2).should.equal(0x1800)

  testAbilityCancelAbility = (name) ->
    describe name, ->
      it "cancels abilities for the duration of the user's move"

  testAbilityCancelAbility("Mold Breaker")
  testAbilityCancelAbility("Teravolt")
  testAbilityCancelAbility("Turboblaze")

  describe "Moody", ->
    it "at turn end, randomly raise a stat by 2 and lower another by 1", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Moody")])
      shared.biasRNG.call(this, "randInt", "moody raise", 1)
      shared.biasRNG.call(this, "randInt", "moody lower", 0)
      @battle.endTurn()
      @p1.stages.should.include(attack: -1, defense: 2)

    it "never raises and lowers the same stat in a single turn", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Moody")])
      shared.biasRNG.call(this, "randInt", "moody raise", 0)
      shared.biasRNG.call(this, "randInt", "moody lower", 0)
      @battle.endTurn()
      @p1.stages.should.include(attack: 2, defense: -1)

    it "does not choose individual stats at max/min", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Moody")])
      shared.biasRNG.call(this, "randInt", "moody raise", 1)
      shared.biasRNG.call(this, "randInt", "moody lower", 0)
      @p1.boost(defense: 6)
      @p1.boost(attack: -6)
      @battle.endTurn()
      @p1.stages.should.include(defense: 5, speed: 2)

    it "does not try to raise a null stat", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Moody")])
      shared.biasRNG.call(this, "randInt", "moody raise", 1)
      shared.biasRNG.call(this, "randInt", "moody lower", 0)
      @p1.boost(attack: 6, defense: 6, speed: 6, specialAttack: 6)
      @p1.boost(specialDefense: 6, accuracy: 6, evasion: 6)
      (=> @battle.endTurn()).should.not.throw()

  testTypeImmuneAbility = (name, type, stat) ->
    describe name, ->
      it "makes the user immune to #{type} moves", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        mock = @sandbox.mock(typedMove).expects('hit').never()
        @battle.performMove(@p2, typedMove)
        mock.verify()

      it "increases #{stat} by 1 if hit by a #{type}-type move", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        @battle.performMove(@p2, typedMove)
        @p1.stages[stat].should.equal(1)

      it "increases #{stat} by only 1 even if move is multi-hit", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type == type
        @sandbox.stub(typedMove, 'calculateNumberOfHits', -> 2)
        @battle.performMove(@p2, typedMove)
        @p1.stages[stat].should.equal(1)

      it "does nothing otherwise", ->
        shared.create.call(this, team1: [Factory("Magikarp", ability: name)])
        typedMove = @battle.MoveList.find (m) ->
          !m.isNonDamaging() && m.type != type
        mock = @sandbox.mock(typedMove).expects('hit').once()
        @battle.performMove(@p2, typedMove)
        @p1.stages[stat].should.equal(0)
        mock.verify()

  testTypeImmuneAbility("Motor Drive", "Electric", "speed")
  testTypeImmuneAbility("Sap Sipper", "Grass", "attack")

  describe "Moxie", ->
    it "increases attack every time it faints another target", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Moxie")]
      tackle = @battle.getMove("Tackle")
      @p2.currentHP = 1
      @p1.stages.should.include(attack: 0)
      @battle.performMove(@p1, tackle)
      @p1.stages.should.include(attack: 1)

  describe "Multiscale", ->
    it "takes half damage at full HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Multiscale")]
      iceBeam = @battle.getMove("Ice Beam")
      iceBeam.modifyDamage(@battle, @p2, @p1).should.equal(0x800)

    it "takes normal damage at other HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Multiscale")]
      iceBeam = @battle.getMove("Ice Beam")
      @p1.currentHP -= 1
      iceBeam.modifyDamage(@battle, @p2, @p1).should.equal(0x1000)

  describe "Multitype", ->
    it "changes Arceus forme for different plates"

  describe "Mummy", ->
    it "changes the attacker's ability to Mummy on contact"
    it "doesn't change ability if move used isn't a contact move"

  describe "Natural Cure", ->
    it "cures status upon switch out", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Natural Cure")]
      @p1.attach(Status.Burn)
      @p1.switchOut(@battle)
      @p1.hasStatus().should.be.false

  describe "No Guard", ->
    it "makes every move by this Pokemon never miss", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "No Guard")]
      focusBlast = @battle.getMove("Focus Blast")
      focusBlast.chanceToHit(@battle, @p1, @p2).should.equal(0)

    it "makes every move against this Pokemon never miss", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "No Guard")]
      focusBlast = @battle.getMove("Focus Blast")
      focusBlast.chanceToHit(@battle, @p2, @p1).should.equal(0)

  describe "Normalize", ->
    it "makes every move act as if it were Normal type", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Normalize")]
        team2: [Factory("Magikarp")]
      thunderbolt = @battle.getMove("Thunderbolt")
      thunderbolt.typeEffectiveness(@battle, @p1, @p2).should.equal(1)

    it "has no effect if target is self", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Normalize")]
        team2: [Factory("Magikarp")]
      thunderbolt = @battle.getMove("Thunderbolt")
      thunderbolt.typeEffectiveness(@battle, @p1, @p1).should.equal(2)

    it "has no effect on struggle", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Normalize")]
        team2: [Factory("Skarmory")]
      struggle = @battle.getMove("Struggle")
      struggle.typeEffectiveness(@battle, @p1, @p2).should.equal(1)

  describe "Overcoat", ->
    it "gives an immunity to adverse weather effects", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Overcoat")]
      @p1.isWeatherDamageImmune(Weather.HAIL).should.be.true
      @p1.isWeatherDamageImmune(Weather.SAND).should.be.true

  describe "Plus", ->
    it "multiplies special attack by 1.5 if on the field with Minus", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp")]
        team2: [Factory("Magikarp"), Factory("Magikarp")]
      specialAttack = @p1.stat('specialAttack')
      @team1.at(0).copyAbility(Ability.Minus)
      @team1.at(1).copyAbility(Ability.Plus)
      thunderbolt = @battle.getMove("Thunderbolt")
      thunderbolt.modifyAttack(@battle, @team1.at(1), @p2).should.equal(0x1800)

  describe "Poison Heal", ->
    it "prevents normal poison damage", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Poison Heal")]
      @p1.attach(Status.Poison)
      @battle.endTurn()
      @p1.currentHP.should.not.be.lessThan @p1.stat('hp')
      @p1.cureStatus()
      @p1.attach(Status.Toxic)
      @battle.endTurn()
      @p1.currentHP.should.not.be.lessThan @p1.stat('hp')

    it "heals 1/8 HP end of turn while poisoned", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Poison Heal")]
      @p1.attach(Status.Poison)
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 3))

    it "heals 1/8 HP end of turn while toxiced", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Poison Heal")]
      @p1.attach(Status.Toxic)
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 3))

  describe "Prankster", ->
    it "makes non-damaging moves have a priority (priority + 1)", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Prankster")]
      spore = @battle.getMove("Spore")
      tackle = @battle.getMove("Tackle")
      action = {type: "move", move: spore}
      @battle.actionPriority(action, @p1).should.equal(spore.priority + 1)
      action.move = tackle
      @battle.actionPriority(action, @p1).should.equal(tackle.priority)

  describe "Pressure", ->
    it "reduces a move's PP further by 1 if targetted by foe's move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Pressure")]
      tackle = @battle.getMove("Tackle")
      @p2.moves = [ tackle ]
      @p2.resetAllPP()
      pp = @p2.pp(tackle)
      @battle.performMove(@p2, tackle)
      @p2.pp(tackle).should.equal(pp - 2)

  describe "Quick Feet", ->
    it "increases speed by x1.5 when statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Quick Feet")]
      speed = @p1.stat('speed')
      @p1.attach(Status.Sleep)
      @p1.stat('speed').should.equal Math.floor(1.5 * speed)

    it "negates speed drop from paralysis", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Quick Feet")]
      speed = @p1.stat('speed')
      @p1.attach(Status.Paralyze)
      @p1.stat('speed').should.equal Math.floor(1.5 * speed)

  describe "Rain Dish", ->
    it "restores 1/16 HP at end of turn under Rain", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Rain Dish")]
      @p1.currentHP = 1
      @battle.setWeather(Weather.RAIN)
      @battle.endTurn()
      @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 4))

    it "does not restore HP at end of turn under non-Rain weather", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Rain Dish")]
      @p1.currentHP = 1
      @battle.endTurn()
      @p1.currentHP.should.equal(1)

  describe "Rattled", ->
    for type in ["Ghost", "Bug", "Dark"]
      do (type) ->
        it "raises speed by 1 when hit by a #{type} move", ->
          shared.create.call this,
            team1: [Factory("Magikarp", ability: "Rattled")]
          typedMove = @battle.MoveList.find (m) ->
            m.type == type
          @p1.stages.speed.should.equal(0)
          @battle.performMove(@p2, typedMove)
          @p1.stages.speed.should.equal(1)

  describe "Reckless", ->
    it "gives a 1.2x boost to recoil moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Reckless")]
      recoilMoves = @battle.MoveList.filter (m) ->
        m.recoil < 0
      for move in recoilMoves
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1333)

    it "boosts the kick moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Reckless")]
      recoilMoves = [ @battle.getMove("Jump Kick"),
                      @battle.getMove("Hi Jump Kick") ]
      for move in recoilMoves
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1333)

    it "does not boost struggle", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Reckless")]
      struggle = @battle.getMove("Struggle")
      struggle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

    it "does not boost drain moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Reckless")]
      absorb = @battle.getMove("Absorb")
      absorb.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Regenerator", ->
    it "restores 1/3 of the user's HP upon switch out", ->
    shared.create.call this,
      team1: [Factory("Magikarp", ability: "Regenerator")]
    @p1.currentHP = 1
    @p1.switchOut(@battle)
    hp = Math.floor(@p1.stat('hp') / 3)
    @p1.currentHP.should.equal(1 + hp)

  describe "Rivalry", ->
    it "reduces base power by 25% if user and target are opposite genders", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: 'F', ability: "Rivalry")]
        team2: [Factory("Magikarp", gender: 'M')]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0xC00)

    it "increases base power by 25% if user and target are the same gender", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: 'F', ability: "Rivalry")]
        team2: [Factory("Magikarp", gender: 'F')]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1400)

    it "has normal base power if either user or target have no gender", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: 'F', ability: "Rivalry")]
        team2: [Factory("Magikarp")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Rock Head", ->
    it "negates recoil", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Rock Head")]
      @battle.performMove(@p1, @battle.getMove("Head Smash"))
      @p1.currentHP.should.equal @p1.stat('hp')

  describe "Sand Force", ->
    it "increases BP of Ground-, Rock-, and Steel-type moves by 30% in sand", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sand Force")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)
      earthquake = @battle.getMove("Earthquake")
      earthquake.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)
      rockSlide = @battle.getMove("Rock Slide")
      rockSlide.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)
      meteorMash = @battle.getMove("Meteor Mash")
      meteorMash.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)

    it "grants immunity to sandstorm", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sand Force")]
      @p1.isWeatherDamageImmune(Weather.SAND).should.be.true

  describe "Sand Veil", ->
    it "increases evasion by 25% in Sand", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sand Veil")]
      @battle.setWeather(Weather.SAND)
      tackle = @battle.getMove("Tackle")
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(80)

    it "does nothing outside of Sand", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sand Veil")]
      tackle = @battle.getMove("Tackle")
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(100)

    it "makes the user immune to Sand", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sand Veil")]
      @p1.isWeatherDamageImmune(Weather.SAND).should.be.true

  describe "Scrappy", ->
    it "negates pokemon immunities", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Scrappy")]
        team2: [Factory("Gengar")]
      tackle = @battle.getMove("Tackle")
      closeCombat = @battle.getMove("Close Combat")
      tackle.typeEffectiveness(@battle, @p1, @p2).should.equal(1)
      closeCombat.typeEffectiveness(@battle, @p1, @p2).should.equal(.5)

  describe "Serene Grace", ->
    it "doubles the chance of secondary effects happening"

  describe "Shadow Tag", ->
    it "prevents foes from switching", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Shadow Tag")]
      @p2.isSwitchBlocked().should.be.true
      @battle.beginTurn()
      @p2.isSwitchBlocked().should.be.true

  describe "Shed Skin", ->
    it "has a 30% chance of removing its status effect at end of turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Shed Skin")]
      shared.biasRNG.call(this, "randInt", "shed skin", 3)
      @p1.attach(Status.Burn)
      @battle.endTurn()
      @p1.has(Status.Burn).should.be.false

    it "has a 70% chance of doing nothing at end of turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Shed Skin")]
      shared.biasRNG.call(this, "randInt", "shed skin", 4)
      @p1.attach(Status.Burn)
      @battle.endTurn()
      @p1.has(Status.Burn).should.be.true

  describe "Sheer Force", ->
    it "raises power of moves with secondary effects by 30%"
    it "nullifies secondary effects"
    it "does not apply to some moves that negatively affect user"
    it "receives no life orb damage"

  describe "Shield Dust", ->
    it "prevents secondary effects"

  describe "Simple", ->
    it "doubles stat boosts, negative and positive", ->
      shared.create.call(this, team1: [Factory("Magikarp", ability: "Simple")])
      @battle.performMove(@p1, @battle.getMove("Curse"))
      @p1.stages.should.include(attack: 2, defense: 2, speed: -2)

  describe "Slow Start", ->
    it "halves attack and speed", ->
      shared.create.call(this)
      speed = @p1.stat('speed')
      @p1.copyAbility(Ability.SlowStart)
      tackle = @battle.getMove("Tackle")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x800)
      flamethrower = @battle.getMove("Flamethrower")
      flamethrower.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      @p1.stat('speed').should.equal(speed >> 1)

    it "returns attack and speed to normal after five turns", ->
      shared.create.call(this)
      tackle = @battle.getMove("Tackle")
      flamethrower = @battle.getMove("Flamethrower")
      speed = @p1.stat('speed')
      @p1.copyAbility(Ability.SlowStart)
      for x in [0...5]
        tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x800)
        flamethrower.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
        @p1.stat('speed').should.equal(speed >> 1)
        @battle.endTurn()
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      flamethrower.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      @p1.stat('speed').should.equal(speed)

  describe "Sniper", ->
    it "multiplies damage by a further x1.5 if critting", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sniper")]
      tackle = @battle.getMove("Tackle")
      @p1.crit = true
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1800)

    it "has a normal 1x multiplier if not critting", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sniper")]
      tackle = @battle.getMove("Tackle")
      @p1.crit = false
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

  describe "Snow Cloak", ->
    it "increases evasion by 25% in hail", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Snow Cloak")]
      @battle.setWeather(Weather.HAIL)
      tackle = @battle.getMove("Tackle")
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(80)

    it "does nothing outside of hail", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Snow Cloak")]
      tackle = @battle.getMove("Tackle")
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(100)

    it "makes the user immune to hail", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Snow Cloak")]
      @p1.isWeatherDamageImmune(Weather.HAIL).should.be.true

  describe "Solar Power", ->
    it "increases special attack by 50% in Sun", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Solar Power")]
      @battle.setWeather(Weather.SUN)
      tackle = @battle.getMove("Tackle")
      fireBlast = @battle.getMove("Fire Blast")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      fireBlast.modifyAttack(@battle, @p1, @p2).should.equal(0x1800)

    it "owner loses 1/8 max HP per end of turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Solar Power")]
      @battle.setWeather(Weather.SUN)
      @battle.endTurn()
      @p1.currentHP.should.equal(@p1.stat('hp') - (@p1.stat('hp') >> 3))

    it "does nothing if the weather is not Sun", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Solar Power")]
      fireBlast = @battle.getMove("Fire Blast")
      fireBlast.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      @battle.endTurn()
      @p1.currentHP.should.equal(@p1.stat('hp'))

  describe "Soundproof", ->
    it "makes user immune to sound moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Soundproof")]
      bugBuzz = @battle.getMove('Bug Buzz')
      perishSong = @battle.getMove('Perish Song')
      @p1.isImmune(bugBuzz.type, bugBuzz).should.be.true
      @p1.isImmune(perishSong.type, perishSong).should.be.true

  describe "Speed Boost", ->
    it "boosts speed at the end of every turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Speed Boost")]
      @p1.stages.should.include(speed: 0)
      @battle.endTurn()
      @p1.stages.should.include(speed: 1)
      @battle.endTurn()
      @p1.stages.should.include(speed: 2)

    it "boosts speed the turn after a pokemon is freshly switched in", ->
      shared.create.call this,
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Speed Boost")]
      @battle.performSwitch(@p1, 1)
      @team1.first().stages.should.include(speed: 0)
      @battle.endTurn()
      @team1.first().stages.should.include(speed: 0)
      @battle.endTurn()
      @team1.first().stages.should.include(speed: 1)
      @battle.endTurn()
      @team1.first().stages.should.include(speed: 2)

  describe "Sticky Hold", ->
    it "prevents items from being taken", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sticky Hold")]
      @p1.hasTakeableItem().should.be.false

  describe "Stall", ->
    it "forces the user to move last no matter what", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4}, ability: "Stall")]
        team2: [Factory("Magikarp")]
      splash = @battle.getMove("Splash")
      @battle.recordMove(@id1, splash)
      @battle.recordMove(@id2, splash)
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p2, @p1 ]

    it "moves before pokemon with lagging tail/full incense", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4}, ability: "Stall")]
        team2: [Factory("Magikarp", item: "Lagging Tail")]
      splash = @battle.getMove("Splash")
      @battle.recordMove(@id1, splash)
      @battle.recordMove(@id2, splash)
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p1, @p2 ]

  describe "Steadfast", ->
    it "raises speed if the Pokemon flinches", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Steadfast")]
      tackle = @battle.getMove("Tackle")
      @p1.attach(Attachment.Flinch)
      @p1.beforeMove(tackle, @p1, [ @p2 ])
      @p1.stages.should.include(speed: 1)

  describe "Sturdy", ->
    it "prevents the user from being OHKOed at full HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sturdy")]
      tackle = @battle.getMove("Tackle")
      @p1.editDamage(tackle, 9999).should.equal(@p1.currentHP - 1)

    it "lets the user be KOed if not at full HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Sturdy")]
      tackle = @battle.getMove("Tackle")
      damage = 9999
      @p1.currentHP -= 1
      @p1.editDamage(tackle, damage).should.equal(damage)

  describe "Suction Cups", ->
    it "prevents user from being phased", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Suction Cups"), Factory("Magikarp")]
      whirlwind = @battle.getMove('Whirlwind')
      mock = @sandbox.mock(@team1).expects('switch').never()
      @battle.performMove(@p2, whirlwind)
      mock.verify()

  describe "Super Luck", ->
    it "adds +2 to critical hit level", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Super Luck")]
      tackle = @battle.getMove("Tackle")
      tackle.criticalHitLevel(@battle, @p1, @p2).should.equal(2)

  describe "Synchronize", ->
    it "afflicts the source of a status with the same status", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Synchronize")]
      @p1.attach(Status.Burn, source: @p2)
      @p2.has(Status.Burn).should.be.true

    it "doesn't attempt to afflict target if target is self", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Synchronize")]
      spy = @sandbox.spy(Status.Burn, 'preattach')
      @p1.attach(Status.Burn, source: @p1)
      spy.returned(false).should.be.true

    it "activates on primary status moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Synchronize")]
      @battle.performMove(@p2, @battle.getMove("Will-O-Wisp"))
      @p2.has(Status.Burn).should.be.true

    it "doesn't activate on Sleep", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Synchronize")]
      @p1.attach(Status.Sleep, source: @p2)
      @p2.has(Status.Sleep).should.be.false

    it "doesn't activate on Freeze", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Synchronize")]
      @p1.attach(Status.Freeze, source: @p2)
      @p2.has(Status.Freeze).should.be.false

  describe "Tangled Feet", ->
    it "doubles evasion rate when confused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Tangled Feet")]
      tackle = @battle.getMove("Tackle")
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(100)
      @p1.attach(Attachment.Confusion)
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(50)
      @p1.unattach(Attachment.Confusion)
      tackle.chanceToHit(@battle, @p2, @p1).should.equal(100)

  describe "Technician", ->
    it "increases base power of moves with BP <= 60 by x1.5", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Technician")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

    it "leaves moves with BP > 60 alone", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Technician")]
      iceBeam = @battle.getMove("Ice Beam")
      iceBeam.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Telepathy", ->
    it "cancels damaging attacks from an ally", ->
      shared.create.call this,
        numActive: 2
        team1: [Factory("Magikarp"), Factory("Magikarp", ability: "Telepathy")]
        team2: (Factory("Magikarp")  for x in [1..2])
      earthquake = @battle.getMove("Earthquake")
      mock = @sandbox.mock(earthquake).expects('hit').exactly(2)
      @battle.performMove(@p1, earthquake)
      @team1.at(1).currentHP.should.equal(@team1.at(1).stat('hp'))
      mock.verify()

  describe "Thick Fat", ->
    it "halves the base power of Fire and Ice moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Thick Fat")]
      iceBeam = @battle.getMove("Ice Beam")
      iceBeam.modifyAttack(@battle, @p2, @p1).should.equal(0x800)
      flamethrower = @battle.getMove("Flamethrower")
      flamethrower.modifyAttack(@battle, @p2, @p1).should.equal(0x800)

    it "doesn't change base power of other moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Thick Fat")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyAttack(@battle, @p2, @p1).should.equal(0x1000)

  describe "Tinted Lens", ->
    it "doubles damage when using a not-very-effective move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Tinted Lens")]
        team2: [Factory("Magikarp")]
      surf = @battle.getMove("Surf")
      surf.modifyDamage(@battle, @p1, @p2).should.equal(0x2000)

    it "doesn't double damage otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Tinted Lens")]
        team2: [Factory("Magikarp")]
      tackle = @battle.getMove("Tackle")
      tackle.modifyDamage(@battle, @p1, @p2).should.equal(0x1000)

  describe "Trace", ->
    it "copies a random foe's ability on switch-in", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Trace")]
        team2: [Factory("Magikarp", ability: "Truant")]
      @p1.hasAbility("Truant").should.be.true

    it "does not copy certain abilities", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Trace")]
        team2: [Factory("Magikarp", ability: "Forecast")]
      @p1.hasAbility("Forecast").should.be.false

  describe "Truant", ->
    it "prevents the user from attacking every other turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Truant")]
      splash = @battle.getMove("Splash")

      mock = @sandbox.mock(splash).expects('execute').once()
      @battle.performMove(@p1, splash)
      mock.verify()
      splash.execute.restore()

      mock = @sandbox.mock(splash).expects('execute').never()
      @battle.performMove(@p1, splash)
      mock.verify()
      splash.execute.restore()

      mock = @sandbox.mock(splash).expects('execute').once()
      @battle.performMove(@p1, splash)
      mock.verify()
      splash.execute.restore()

  describe "Unaware", ->
    it "ignores attackers' attack, special attack, and accuracy boosts"
    it "ignores defenders' defense, special defense, and evasion boosts"

  describe "Unburden", ->
    it "doubles its speed when the owner's item is removed", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flying Gem", ability: "Unburden")]
      speed = @p1.stat('speed')
      @p1.removeItem()
      @p1.stat('speed').should.equal(2 * speed)

  describe "Unnerve", ->
    it "prevents held berries from being eaten", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Unnerve")]
        team2: [Factory("Magikarp", item: "Salac Berry")]
      @p2.currentHP = 1
      @p2.update()
      @p2.stages.should.include(speed: 0)
      @battle.beginTurn()
      @p2.update()
      @p2.stages.should.include(speed: 0)

    it "does not prevent regular item usage", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Unnerve")]
        team2: [Factory("Magikarp", item: "Leftovers")]
      @p2.currentHP = 1
      @battle.endTurn()
      @p2.currentHP.should.be.greaterThan(1)

    it "does not prevent Bug Bite, Pluck, etc. from working", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry", ability: "Unnerve")]
      @battle.performMove(@p2, @battle.getMove("Bug Bite"))
      @p2.stages.should.include(speed: 1)

  describe "Victory Star", ->
    it "increases accuracy of moves by 10%", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Victory Star")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      accuracy = willOWisp.chanceToHit(@battle, @p1, @p2)
      accuracy.should.equal Math.floor(willOWisp.accuracy * 1.1)

    it "increases accuracy of ally moves by 10%"

  testTypeAbsorbMove = (name, type) ->
    describe name, ->
      it "is immune to #{type}-type moves", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        typedMove = @battle.MoveList.find (m) ->
          m.type == type
        mock = @sandbox.mock(typedMove).expects('hit').never()
        @battle.performMove(@p2, typedMove)
        mock.verify()

      it "heals 25% HP from #{type}-type moves", ->
        shared.create.call this,
          team1: [Factory("Magikarp", ability: name)]
        typedMove = @battle.MoveList.find (m) ->
          m.type == type
        @p1.currentHP = 1
        @battle.performMove(@p2, typedMove)
        @p1.currentHP.should.equal(1 + (@p1.stat('hp') >> 2))

  testTypeAbsorbMove("Water Absorb", "Water")
  testTypeAbsorbMove("Volt Absorb", "Electric")

  describe "Weak Armor", ->
    it "lowers defense and raises speed on physical attacks", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Weak Armor")]
      tackle = @battle.getMove("Tackle")
      @battle.performMove(@p2, tackle)
      @p1.stages.should.include(defense: -1, speed: 1)

    it "does nothing on any other kind of move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Weak Armor")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      @battle.performMove(@p2, willOWisp)
      @p1.stages.should.include(defense: 0, speed: 0)

  describe "Wonder Guard", ->
    it "renders the Pokemon immune to non-super-effective moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Wonder Guard")]
      tackle = @battle.getMove("Tackle")
      mock = @sandbox.mock(tackle).expects('hit').never()
      @battle.performMove(@p2, tackle)
      mock.verify()

    it "is not immune to struggle", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Wonder Guard")]
      struggle = @battle.getMove("Struggle")
      mock = @sandbox.mock(struggle).expects('hit').once()
      @battle.performMove(@p2, struggle)
      mock.verify()

    it "is not immune to non-damaging moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Wonder Guard")]
      willOWisp = @battle.getMove("Will-O-Wisp")
      mock = @sandbox.mock(willOWisp).expects('hit').once()
      @battle.performMove(@p2, willOWisp)
      mock.verify()

    it "is not immune to super-effective moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Wonder Guard")]
      typedMove = @battle.MoveList.find (m) ->
        !m.isNonDamaging() && m.type == 'Electric'
      mock = @sandbox.mock(typedMove).expects('hit').once()
      @battle.performMove(@p2, typedMove)
      mock.verify()

  describe "Wonder Skin", ->
    it "makes non-damaging moves with over 50% accuracy have 50% accuracy"
    it "adjusts accuracy before any other modifiers take effect"
    it "does nothing to non-damaging moves with under 50% accuracy"

  describe "Zen Mode", ->
    it "changes Darmanitan's forme when going under or above 50% HP"
