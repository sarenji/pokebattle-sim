{Attachment, Status} = require('../../server/xy/attachment')
{Battle} = require('../../server/xy/battle')
{Pokemon} = require('../../server/xy/pokemon')
{Weather} = require('../../shared/weather')
{Ability} = require '../../server/xy/data/abilities'
{Item} = require '../../server/xy/data/items'
util = require '../../server/xy/util'
{Factory} = require '../factory'
should = require 'should'
shared = require '../shared'

require '../helpers'

describe "XY Abilities:", ->
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

      it "is lengthened by rocks", ->
        for itemName, item of Item
          break  if item.lengthensWeather == weather
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name, item: itemName)]
        @battle.weatherDuration.should.equal(8)

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
        @battle.performMove(@p1, tackle)
        spy.returned(type).should.be.true

      it "does not change non-Normal-type moves used by attacker", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        spy = @sandbox.spy(@p1, 'editMoveType')
        ember = @battle.getMove('Ember')
        @battle.performMove(@p1, ember)
        spy.returned(type).should.be.false
        spy.returned(ember.type).should.be.true

      it "boosts Normal-type moves by 1.3x", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        tackle = @battle.getMove('Tackle')
        tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)

      it "does not boost regular #{type}-type moves", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        for move in @battle.MoveList
          if move.type == type && !move.isNonDamaging() then break
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

      it "does not boost non-#{type}-type moves", ->
        shared.create.call(this, gen: 'xy', team1: [Factory("Magikarp", ability: name)])
        ember = @battle.getMove('Ember')
        ember.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

      it "is unaffected by the original immunities", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
          team2: [Factory("Gengar")]
        tackle = @battle.getMove('Tackle')
        mock = @sandbox.mock(tackle).expects('hit').once()
        @battle.performMove(@p1, tackle)
        mock.verify()

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
      it "raises base power of #{type} attacks by 1.33x", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
        move = @battle.findMove (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1547)

      it "decreases #{type} attacks by 3/4x if Aura Break is on the field", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", ability: name)]
          team2: [Factory("Magikarp", ability: "Aura Break")]
        move = @battle.findMove (m) ->
          m.type == type && !m.isNonDamaging()
        move.modifyBasePower(@battle, @p1, @p2).should.equal(0xC00)

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
      @p1.isImmune(shadowBall.type, move: shadowBall).should.be.true

  describe "Competitive", ->
    it "boosts special attack by 2 every time a stat is lowered", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Competitive")]
      @p1.boost(defense: -1, @p2)
      @p1.stages.should.include(specialAttack: 2)
      @p1.boost(specialAttack: -1, defense: -2, evasion: 1, @p2)
      @p1.stages.should.include(specialAttack: 5)

    it "does not boost special attack if the stat was self-lowered", ->
      shared.create.call this,
        team1: [Factory("Magikarp", ability: "Competitive")]
      @battle.performMove(@p1, @battle.getMove("Close Combat"))
      boosts = {specialAttack: 0, defense: -1, specialDefense: -1}
      @p1.stages.should.include(boosts)

  describe "Fur Coat", ->
    it "modifies physical attacks by 0x800", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "Fur Coat")]
      tackle = @battle.getMove('Tackle')
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x800)

    it "doesn't modify other attacks", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "Fur Coat")]
      thunderbolt = @battle.getMove('Thunderbolt')
      thunderbolt.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Gooey", ->
    it "lowers the attacker's speed by 1 on contact", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "Gooey")]
      tackle = @battle.getMove('Tackle')
      @p1.stages.should.include(speed: 0)
      @battle.performMove(@p1, tackle)
      @p1.stages.should.include(speed: -1)

    it "does not lower the attacker's speed by 1 on non-contact", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "Gooey")]
      thunderbolt = @battle.getMove('Thunderbolt')
      @p1.stages.should.include(speed: 0)
      @battle.performMove(@p1, thunderbolt)
      @p1.stages.should.include(speed: 0)

    it "works even if the defender faints", ->
      shared.create.call this,
        gen: 'xy'
        team2: [Factory("Magikarp", ability: "Gooey"), Factory("Magikarp")]
      @p2.currentHP = 1
      tackle = @battle.getMove('Tackle')
      @p1.stages.should.include(speed: 0)
      @battle.performMove(@p1, tackle)
      @p1.stages.should.include(speed: -1)

  describe "Mega Launcher", ->
    it "boosts pulse moves by x1.5", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Mega Launcher")]
      waterPulse = @battle.getMove('Water Pulse')
      waterPulse.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

    it "does not boost non-pulse moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Mega Launcher")]
      tackle = @battle.getMove('Tackle')
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Overcoat", ->
    it "makes the user immune to weather", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Overcoat")]
      @p1.isWeatherDamageImmune(Weather.SAND).should.be.true
      @p1.isWeatherDamageImmune(Weather.HAIL).should.be.true

    it "makes the user immune to powder moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Overcoat")]
      spore = @battle.getMove("Spore")
      mock = @sandbox.mock(spore).expects('hit').never()
      @battle.performMove(@p2, spore)
      mock.verify()

  describe "Parental Bond", ->
    it "hits twice if the move has only one target", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      tackle = @battle.getMove('Tackle')
      targets = @battle.getTargets(tackle, @p1)
      tackle.calculateNumberOfHits(@battle, @p1, targets).should.equal(2)

    it "hits once if the move has multiple targets", ->
      shared.create.call this,
        gen: 'xy'
        numActive: 2
        team1: [Factory("Magikarp", ability: "Parental Bond"), Factory("Magikarp")]
        team2: (Factory("Magikarp")  for x in [0..1])
      earthquake = @battle.getMove('Earthquake')
      targets = @battle.getTargets(earthquake, @p1)
      earthquake.calculateNumberOfHits(@battle, @p1, targets).should.equal(1)

    it "hits once if the move is non-damaging", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      willOWisp = @battle.getMove('Will-O-Wisp')
      targets = @battle.getTargets(willOWisp, @p1)
      willOWisp.calculateNumberOfHits(@battle, @p1, targets).should.equal(1)

    it "hits for half damage the second hit", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      tackle = @battle.getMove('Tackle')
      spy = @sandbox.spy(tackle, 'modifyDamage')
      @battle.performMove(@p1, tackle)
      spy.calledTwice.should.be.true
      spy.returnValues[0].should.equal(0x1000)
      spy.returnValues[1].should.equal(0x800)

    it "hits the same number otherwise if the move is multi-hit", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      shared.biasRNG.call(this, "choice", 'num hits', 4)
      shared.biasRNG.call(this, "randInt", 'num hits', 4)
      pinMissile = @battle.getMove('Pin Missile')
      targets = @battle.getTargets(pinMissile, @p1)
      pinMissile.calculateNumberOfHits(@battle, @p1, targets).should.equal(4)

    it "doesn't hit for half damage on the second hit using multi-hit moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      shared.biasRNG.call(this, "choice", 'num hits', 4)
      shared.biasRNG.call(this, "randInt", 'num hits', 4)
      pinMissile = @battle.getMove('Pin Missile')
      spy = @sandbox.spy(pinMissile, 'modifyDamage')
      @battle.performMove(@p1, pinMissile)
      spy.callCount.should.equal(4)
      spy.returnValues[0].should.equal(0x1000)
      spy.returnValues[1].should.equal(0x1000)

    it "recoils only once, but with both attack damages combined", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Parental Bond")]
      takeDown = @battle.getMove("Take Down")
      spy = @sandbox.spy(takeDown, 'hit')
      @battle.performMove(@p1, takeDown)
      totalDamage = spy.returnValues.reduce((a, b) -> a + b)
      recoilDamage = Math.round(totalDamage * -takeDown.recoil / 100)
      (@p1.stat('hp') - @p1.currentHP).should.equal(recoilDamage)

  describe "Protean", ->
    it "changes the Pokemon's type when using a move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Protean")]
      @p1.types.should.eql([ "Water" ])
      @controller.makeMove(@id1, "Tackle")
      @controller.makeMove(@id2, "Splash")
      @p1.types.should.eql([ "Normal" ])

  describe "Stance Change", ->
    it "changes to blade forme when using an attacking move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Aegislash", ability: "Stance Change")]
      @p1.forme.should.equal("default")
      @battle.performMove(@p1, @battle.getMove("Shadow Sneak"))
      @p1.forme.should.equal("blade")

    it "changes to shield forme when using King's Shield", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Aegislash", ability: "Stance Change")]
      @battle.performMove(@p1, @battle.getMove("Shadow Sneak"))
      @p1.forme.should.equal("blade")
      @battle.performMove(@p1, @battle.getMove("King's Shield"))
      @p1.forme.should.equal("default")

    it "changes to shield forme after switching out and back in", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Aegislash", ability: "Stance Change"), Factory("Magikarp")]
      @battle.performMove(@p1, @battle.getMove("Shadow Sneak"))
      @p1.forme.should.equal("blade")
      @battle.performSwitch(@p1, 1)
      @battle.performSwitch(@team1.first(), 1)
      @p1.forme.should.equal("default")

    it "does not change formes when using any other move", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Aegislash", ability: "Stance Change")]
      @battle.performMove(@p1, @battle.getMove("Swords Dance"))
      @p1.forme.should.equal("default")
      @battle.performMove(@p1, @battle.getMove("Shadow Sneak"))
      @p1.forme.should.equal("blade")
      @battle.performMove(@p1, @battle.getMove("Swords Dance"))
      @p1.forme.should.equal("blade")

    it "doesn't attempt to change forme for Pokemon who aren't Aegislash", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Ditto", ability: "Stance Change")]
      @battle.performMove(@p1, @battle.getMove("Shadow Sneak"))
      @p1.forme.should.not.equal("blade")

    it "doesn't attempt to change forme to default for non-Aegislashes", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Rotom", forme: "wash", ability: "Stance Change")]
      @battle.performMove(@p1, @battle.getMove("King's Shield"))
      @p1.forme.should.not.equal("default")

    it "cannot be skill-swapped"
    it "cannot be replaced with another ability"

  describe "Strong Jaw", ->
    it "boosts bite moves by x1.5", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Strong Jaw")]
      bite = @battle.getMove('Bite')
      bite.modifyBasePower(@battle, @p1, @p2).should.equal(0x1800)

    it "does not boost non-bite moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Strong Jaw")]
      thunderbolt = @battle.getMove('Thunderbolt')
      thunderbolt.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Tough Claws", ->
    it "boosts contact moves by x1.3", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Tough Claws")]
      tackle = @battle.getMove('Tackle')
      tackle.modifyBasePower(@battle, @p1, @p2).should.equal(0x14CD)

    it "does not boost non-contact moves", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Tough Claws")]
      thunderbolt = @battle.getMove('Thunderbolt')
      thunderbolt.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

  describe "Mummy", ->
    it "doesn't change ability if attacker has Stance Change", ->
      shared.create.call this,
        gen: 'xy'
        team1: [Factory("Magikarp", ability: "Mummy")]
        team2: [Factory("Magikarp", ability: "Stance Change")]
      tackle = @battle.getMove("Tackle")
      @p2.hasAbility("Mummy").should.be.false
      @battle.performMove(@p2, tackle)
      @p2.hasAbility("Mummy").should.be.false

  testAttachmentImmuneAbility = (name, attachments, options = {}) ->
    describe name, ->
      it "prevents the pokemon from receiving a specific attachment", ->
        shared.create.call this,
          gen: 'xy'
          team1: [Factory("Magikarp", gender: "F", ability: name)]
          team2: [Factory("Magikarp", gender: "M")]
        for attachment in attachments
          should.not.exist @p1.attach(attachment, source: @p2)
          @p1.has(attachment).should.be.false

      shouldCure = options.cure ? true
      if shouldCure
        it "removes the attachment if the pokemon already has it", ->
          shared.create.call this,
            gen: 'xy'
            team1: [Factory("Magikarp", gender: "F")]
            team2: [Factory("Magikarp", gender: "M")]
          for attachment in attachments
            @p1.attach(attachment, source: @p2)
            @p1.has(attachment).should.be.true
            @p1.copyAbility(Ability[name.replace(/\s+/g, '')])
            @p1.update()
            @p1.has(attachment).should.be.false
            @p1.copyAbility(null)

  testAttachmentImmuneAbility("Aroma Veil", [Attachment.Attract, Attachment.Disable,
    Attachment.Encore, Attachment.Taunt, Attachment.Torment], cure: false)
  testAttachmentImmuneAbility("Oblivious", [Attachment.Attract, Attachment.Taunt])
  testAttachmentImmuneAbility("Sweet Veil", [Status.Sleep], cure: false)
