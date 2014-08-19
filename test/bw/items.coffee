require '../helpers'

{Item} = require('../../server/bw/data/items')
{Ability} = require('../../server/bw/data/abilities')
{Pokemon} = require '../../server/bw/pokemon'
{Attachment, Status} = require '../../server/bw/attachment'
{Move} = require '../../server/bw/move'
{Factory} = require '../factory'
util = require '../../server/bw/util'
should = require 'should'
sinon = require 'sinon'
{_} = require 'underscore'
shared = require '../shared'

describe "BW Items:", ->
  describe "Leftovers", ->
    it "heals 1/16 of a pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Leftovers')]
      @p1.currentHP = 1
      @battle.endTurn()
      amount = Math.floor(@p1.stat('hp') / 16)
      @p1.currentHP.should.equal(1 + amount)

  describe "Black Sludge", ->
    it "heals 1/16 of a poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Weezing', item: 'Black Sludge')]
      @p1.currentHP = 1
      @battle.endTurn()
      amount = Math.floor(@p1.stat('hp') / 16)
      @p1.currentHP.should.equal(1 + amount)

    it "damages 1/8 of a non-poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Black Sludge')]
      @battle.endTurn()
      fullHP = @p1.stat('hp')
      amount = Math.floor(fullHP / 8)
      (fullHP - @p1.currentHP).should.equal(amount)

  describe "Muscle Band", ->
    it "increases base power of physical moves by 0x1199", ->
      shared.create.call(this)
      move = @battle.getMove('Tackle')
      modifier = Item.MuscleBand::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1199

      move = @battle.getMove('Shadow Ball')
      modifier = Item.MuscleBand::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1000

  describe "Wise Glasses", ->
    it "increases base power of special moves by 0x1199", ->
      shared.create.call(this)
      move = @battle.getMove('Tackle')
      modifier = Item.WiseGlasses::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1000

      move = @battle.getMove('Shadow Ball')
      modifier = Item.WiseGlasses::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1199

  describe "An Orb item", ->
    it "increases base power of moves matching the user's type by 0x1333", ->
      shared.create.call this,
        team1: [Factory('Giratina', item: "Griseous Orb")]
      move = @battle.getMove('Outrage')
      modifier = move.modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1333

      move = @battle.getMove('Shadow Ball')
      modifier = move.modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1333

      move = @battle.getMove('Tackle')
      modifier = move.modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1000

  describe "A type-boosting miscellaneous item", ->
    it "increases base power of certain typed moves by 0x1333", ->
      shared.create.call(this)
      move = @battle.getMove('Outrage')
      modifier = Item.OddIncense::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1000

      move = @battle.getMove('Psychic')
      modifier = Item.OddIncense::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1333

  describe "A typed Gem", ->
    it "increases base power of certain typed moves by 0x1800", ->
      shared.create.call(this)
      move = @battle.getMove('Acrobatics')
      modifier = Item.FlyingGem::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1800

      move = @battle.getMove('Psychic')
      modifier = Item.FlyingGem::modifyBasePower(move, @p1, @p2)
      modifier.should.equal 0x1000

    it "is removed after use", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @battle.performMove(@p1, @battle.getMove("Acrobatics"))
      @p1.hasItem().should.equal.false

    it "is not removed after use if the move isn't the right type", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      @p1.hasItem("Flying Gem").should.equal.true

  describe "A typed plate", ->
    it "has the plate attribute set", ->
      item = Item.DracoPlate
      item.should.have.property('plate')

    it "changes the Arceus type"

  describe "Rocky Helmet", ->
    it "deals 1/6 of the attacker's total HP on a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @p1.stat('hp')
      currentHP = @p1.currentHP = Math.floor(hp * 2 / 3)
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      @p1.currentHP.should.equal currentHP - Math.floor(hp / 6)

    it "doesn't deal damage back to attacker if not a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @p1.stat('hp')
      currentHP = @p1.currentHP = Math.floor(hp * 2 / 3)
      @battle.performMove(@p1, @battle.getMove("Earthquake"))
      @p1.currentHP.should.equal currentHP

    it "stacks with each hit of multi-hit moves like Triple Kick", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      @battle.performMove(@p1, @battle.getMove("Triple Kick"))
      maxHP = @p1.stat('hp')
      @p1.currentHP.should.equal(maxHP - (Math.floor(maxHP / 6) * 3))

    it "still works even if user faints", ->
      shared.create.call this,
        team2: [Factory('Magikarp', item: 'Rocky Helmet'), Factory("Magikarp")]

      @p2.currentHP = 1
      hp = @p1.stat('hp')
      @battle.performMove(@p1, @battle.getMove("Tackle"))
      @p1.currentHP.should.equal(hp - Math.floor(hp / 6))

  testBoostOnTypeItem = (itemName, type, stat) ->
    describe itemName, ->
      it "boosts the special attack of the target by 1 if hit by a #{type} move", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        move = _(@battle.MoveList).find (m) ->
            m.type == type && !m.isNonDamaging()
        @battle.performMove(@p1, move)
        @p2.stages[stat].should.equal 1

      it "is one-time use", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        move = _(@battle.MoveList).find (m) ->
            m.type == type && !m.isNonDamaging()
        @battle.performMove(@p1, move)
        should.not.exist @p2.item

      it "doesn't boost target's special attack if not hit by a #{type} move", ->
        shared.create.call this,
          team2: [Factory("Ferrothorn", item: itemName)]
        move = _(@battle.MoveList).find (m) ->
            m.type != type && !m.isNonDamaging()
        @battle.performMove(@p1, move)
        @p2.stages[stat].should.equal 0

  testBoostOnTypeItem("Absorb Bulb", "Water", "specialAttack")
  testBoostOnTypeItem("Cell Battery", "Electric", "attack")

  describe "Float Stone", ->
    it "halves the user's weight", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Float Stone")]

      weight = @p1.weight
      @p1.calculateWeight().should.equal Math.floor(weight / 2)

  describe "Focus Sash", ->
    it "always lets the user survive at 100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      @p2.damage(9999)
      @p2.currentHP.should.equal(1)

    it "fails to protect from multihit moves", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      overpoweredMultihitMove = new Move(null, minHits: 5, maxHits: 5, target: "selected-pokemon")
      overpoweredMultihitMove.calculateDamage = -> 99999

      @battle.performMove(@p1, overpoweredMultihitMove)
      @p2.isFainted().should.be.true

    it "triggers on the first hit of a multihit move if each strike OHKOs", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      overpoweredMultihitMove = new Move(null, minHits: 2, maxHits: 2, target: "selected-pokemon")
      overpoweredMultihitMove.calculateDamage = -> 99999
      spy = @sandbox.spy(overpoweredMultihitMove, 'hit')

      @battle.performMove(@p1, overpoweredMultihitMove)
      sinon.assert.calledTwice(spy)

    it "should not activate at <100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      @p2.currentHP -= 1
      @p2.damage(9999)
      @p2.currentHP.should.equal(0)

    it "disappears after activation", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      ember = @battle.getMove('Ember')
      stub = @sandbox.stub(ember, 'calculateDamage', -> 9999)
      @battle.performMove(@p1, ember)
      @p2.hasItem().should.be.false

  describe "Choice items", ->
    it "locks the user into its first selected move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      requestedMoves = @battle.requestFor(@p1).moves
      requestedMoves.should.eql [ @battle.getMove('Splash').name ]

    it "locks the user if it gains the item after an attack", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @battle.performMove(@p1, @battle.getMove('Trick'))
      @battle.performMove(@p2, @battle.getMove('Splash'))
      @battle.beginTurn()
      requestedMoves = @battle.requestFor(@p2).moves
      requestedMoves.should.eql [ @battle.getMove('Splash').name ]

    it "does not automatically lock the user when it switches back in", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band"), Factory("Magikarp")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @controller.makeSwitch(@id1, 1)
      @controller.makeMove(@id2, 'Splash')

      @controller.makeSwitch(@id1, 1)
      @controller.makeMove(@id2, 'Splash')

      request = @battle.requestFor(@p1)
      should.exist(request)
      request.moves.should.eql [ @battle.getMove('Splash').name, @battle.getMove('Tackle').name ]

    it "increases the respective stat by 1.5", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band")]
      tackle = @battle.getMove("Tackle")
      thunder = @battle.getMove("Thunder")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1800)
      thunder.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)

    xit "relocks the pokemon after Magic Room"

  describe "Choice Scarf", ->
    it "increases the speed of the Pokemon by x1.5", ->
      shared.create.call(this)

      speed = @p1.stat('speed')
      @p1.setItem(Item.ChoiceScarf)
      @p1.stat('speed').should.equal Math.floor(speed * 1.5)

  describe "Flame Orb", ->
    it "burns the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Status.Burn).should.be.true

    it "does not burn the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @p1.attach(Status.Sleep)

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Status.Burn).should.be.false

  describe "Toxic Orb", ->
    it "toxics the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Status.Toxic).should.be.true

    it "does not toxic the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @p1.attach(Status.Sleep)

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Status.Toxic).should.be.false

  describe "Air Balloon", ->
    it "makes the user immune to ground moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      move = @battle.getMove('Earthquake')
      type = move.getType(@battle, @p1, @p2)
      @p1.isImmune(type).should.be.true

    it "pops if hit by an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Tackle')

      @p1.hasItem().should.be.false

    it "does not pop if hit by a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @battle.performMove(@p2, @battle.getMove('Flatter'))
      @p1.hasItem().should.be.true

    it "no longer makes the pokemon immune when popped", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Tackle')

      move = @battle.getMove('Earthquake')
      type = move.getType(@battle, @p1, @p2)
      @p1.isImmune(type).should.be.false

    it "stops effecting a pokemon if Tricked away", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @battle.performMove(@p2, @battle.getMove('Trick'))
      @p1.has(Item.AirBalloon).should.be.false
      @p2.has(Item.AirBalloon).should.be.true

  describe "White Herb", ->
    it "negates negative status boosts", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "White Herb")]

      @battle.performMove(@p1, @battle.getMove('Shell Smash'))
      @p1.update()
      @p1.stages.should.containEql {
        attack: 2, defense: 0, speed: 2, specialAttack: 2, specialDefense: 0
      }

  describe "Life Orb", ->
    it "removes 10% from the pokemon's HP when using an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      hp = @p1.stat('hp')
      (hp - @p1.currentHP).should.equal Math.floor(hp / 10)

    it "only recoils once in a multi-hit move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @battle.performMove(@p1, @battle.getMove("Fury Swipes"))

      maxHP = @p1.stat('hp')
      (maxHP - @p1.currentHP).should.equal Math.floor(maxHP / 10)

    it "doesn't remove 10% HP when using a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @battle.performMove(@p1, @battle.getMove('Growl'))
      @p1.currentHP.should.equal @p1.stat('hp')

    it "adds a x1.3 modifier to attacks", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      tackle = @battle.getMove("Tackle")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x14CC)

  describe "Salac berry", ->
    it "raises the Pokemon's Speed when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.stages.speed.should.equal(0)

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.stages.speed.should.equal(1)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.false

  describe "Starf berry", ->
    it "sharply raises a random stat when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.stages.defense.should.equal(2)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.false

    it "only raises stats that aren't at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @p1.stages.defense = 6
      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      # Note: This depends on the stats array inside
      # the definition of Starf Berry. Not exactly robust.
      @p1.stages.specialAttack.should.equal(2)
      @p1.hasItem().should.be.false

    it "doesn't raise any stat if all main stats are at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      stats = ["attack", "defense", "specialAttack", "specialDefense", "speed"]
      for stat in stats
        @p1.stages[stat] = 6

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      hash = {}
      for stat in stats
        hash[stat] = 6
      @p1.stages.should.containEql(hash)
      @p1.hasItem().should.be.false

  describe "a flavor healing berry", ->
    it "restores 1/8 of the Pokemon's HP when at 50% HP or under", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.true

      maxHP = @p1.stat('hp')
      hp = Math.floor(maxHP / 2)
      @p1.currentHP = hp
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.currentHP.should.equal(hp + Math.floor(maxHP / 8))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry")]

      @p1.currentHP = Math.floor(@p1.stat('hp') / 2)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.false

    it "confuses the owner if its nature decreases a specific stat", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Figy Berry", nature: "Calm")]

      @p1.currentHP = Math.floor(@p1.stat('hp') / 2)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.has(Attachment.Confusion).should.be.true

  describe "a healing berry", ->
    it "restores a variable number of HP when owner is at 50% HP or under", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sitrus Berry")]

      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.true

      maxHP = @p1.stat('hp')
      hp = Math.floor(maxHP / 2)
      @p1.currentHP = hp
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.currentHP.should.equal(hp + Math.floor(maxHP / 4))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sitrus Berry")]

      @p1.currentHP = Math.floor(@p1.stat('hp') / 2)
      @controller.makeMove(@id1, 'Splash')
      @controller.makeMove(@id2, 'Splash')

      @p1.hasItem().should.be.false

  describe "a type-resist berry", ->
    it "halves base power of a super-effective move used on the target", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      move = @battle.getMove('Earthquake')
      move.modifyBasePower(@battle, @p1, @p2).should.equal(0x800)

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      @battle.performMove(@p1, @battle.getMove("Earthquake"))
      @p2.hasItem().should.be.false

    it "is not triggered by non-damaging moves", ->
      shared.create.call this,
        team2: [Factory("Celebi", item: "Occa Berry")]

      @battle.performMove(@p1, @battle.getMove("Will-O-Wisp"))
      @p2.hasItem().should.be.true

    it "does not halve if the move is not of the required type", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      move = @battle.getMove('Surf')
      move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

    it "does not halve if the move is not super-effective", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Shuca Berry")]

      move = @battle.getMove('Earthquake')
      move.modifyBasePower(@battle, @p1, @p2).should.equal(0x1000)

    it "halves nevertheless, if it's the normal-resist berry", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Chilan Berry")]

      move = @battle.getMove('Double-Edge')
      move.modifyBasePower(@battle, @p1, @p2).should.equal(0x800)

    it "halves base power of moves even if they aren't naturally that type", ->
      shared.create.call this,
        team2: [Factory("Blaziken", item: "Shuca Berry")]

      move = @battle.getMove('Tackle')
      @sandbox.stub(move, 'getType', -> 'Ground')
      move.modifyBasePower(@battle, @p1, @p2).should.equal(0x800)

  describe "a feedback damage berry", ->
    it "damages the attacker by 12.5% if move class matches", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Jaboca Berry")]

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      hp = @p1.stat('hp')
      (hp - @p1.currentHP).should.equal Math.floor(hp / 8)

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Jaboca Berry")]

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      @p2.hasItem().should.be.false

    it "does not damage the attacker by 12.5% if move class doesn't match", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Rowap Berry")]

      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      @p1.currentHP.should.equal @p1.stat('hp')

    it "does not damage the attacker if defender faints", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Rowap Berry")]

      @p2.currentHP = 1
      @controller.makeMove(@id1, 'Tackle')
      @controller.makeMove(@id2, 'Splash')

      @p1.currentHP.should.equal @p1.stat('hp')

  describe "status cure berries", ->
    it "restores certain statuses", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Cheri Berry")]

      @p2.attach(Status.Paralyze)
      @p2.update()
      @p2.has(Status.Paralyze).should.be.false

    it "is consumed after use", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Cheri Berry")]

      @p2.attach(Status.Paralyze)
      @p2.update()
      @p2.hasItem().should.be.false

    it "restores confusion", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Lum Berry")]

      shared.biasRNG.call(this, "randInt", 'confusion turns', 4)
      @p2.attach(Attachment.Confusion, {@battle})
      @p2.update()
      @p2.has(Attachment.Confusion).should.be.false

    it "sends a message about status being restored", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Lum Berry")]

      spy = @sandbox.spy(@battle, 'message')
      shared.biasRNG.call(this, "randInt", 'confusion turns', 4)
      @p2.attach(Attachment.Confusion, {@battle})
      @p2.update()
      spy.args.join(',').should.containEql("#{@p1.name}'s Lum Berry snapped it out of its confusion!")

  describe "Enigma Berry", ->
    it "restores 25% of HP after the owner is hit by a super-effective move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      hp = @p1.stat('hp')
      damage = Math.floor(hp / 2)
      thunderbolt = @battle.getMove("Thunderbolt")
      @sandbox.stub(thunderbolt, "calculateDamage", -> damage)
      @battle.performMove(@p2, thunderbolt)
      @p1.currentHP.should.equal(hp - damage + Math.floor(hp / 4))

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      @battle.performMove(@p2, @battle.getMove("Thunderbolt"))
      @p1.hasItem().should.be.false

    it "doesn't restore 25% of HP if move isn't super-effective", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Enigma Berry")]

      hp = @p1.stat('hp')
      damage = Math.floor(hp / 2)
      tackle = @battle.getMove("Tackle")
      @sandbox.stub(tackle, "calculateDamage", -> damage)
      @battle.performMove(@p2, tackle)
      @p1.currentHP.should.equal(hp - damage)

  testSpeciesBoostingItem = (itemName, speciesArray, statsHash) ->
    describe itemName, ->
      for species in speciesArray
        it "should raise the proper stats given that the wielder is #{species}", ->
          shared.create.call this,
            team1: [Factory(species)]

          stats = (stat  for stat of statsHash)
          pokemonStats = (@p1.stat(stat)  for stat in stats)

          @p1.setItem(Item[itemName.replace(/\s+/g, '')])

          for stat, i in stats
            amount = @p1.stat(stat)
            amount.should.equal Math.floor(pokemonStats[i] * statsHash[stat])

      it "shouldn't raise the proper stats given the wrong species", ->
          shared.create.call this,
            team1: [Factory("Magikarp")]

          stats = (stat  for stat of statsHash)
          pokemonStats = (@p1.stat(stat)  for stat in stats)

          @p1.setItem(Item[itemName.replace(/\s+/g, '')])

          for stat, i in stats
            amount = @p1.stat(stat)
            amount.should.equal(pokemonStats[i])

      it "shouldn't raise the proper stats given the pokemon is Transformed", ->
          shared.create.call this,
            team1: [Factory(species)]
            team2: [Factory("Magikarp")]

          @p1.attach(Attachment.Transform, target: @p2)
          stats = (stat  for stat of statsHash)
          pokemonStats = (@p1.stat(stat)  for stat in stats)

          @p1.setItem(Item[itemName.replace(/\s+/g, '')])

          for stat, i in stats
            amount = @p1.stat(stat)
            amount.should.equal(pokemonStats[i])

  testSpeciesBoostingItem("Soul Dew", ["Latios", "Latias"],
    specialAttack: 1.5, specialDefense: 1.5)
  testSpeciesBoostingItem("DeepSeaTooth", ["Clamperl"], specialAttack: 2)
  testSpeciesBoostingItem("DeepSeaScale", ["Clamperl"], specialDefense: 2)
  testSpeciesBoostingItem("Light Ball", ["Pikachu"], attack: 2, specialAttack: 2)
  testSpeciesBoostingItem("Thick Club", ["Cubone", "Marowak"], attack: 2)
  testSpeciesBoostingItem("Metal Powder", ["Ditto"],
    defense: 2, specialDefense: 2)
  testSpeciesBoostingItem("Quick Powder", ["Ditto"], speed: 2)

  describe "Iron Ball", ->
    it "halves the owner's speed", ->
      shared.create.call(this)

      speed = @p1.stat('speed')
      @p1.setItem(Item.IronBall)
      @p1.stat('speed').should.equal Math.floor(speed / 2)

    it "removes the immunity to ground-type moves", ->
      shared.create.call(this, team1: [Factory("Gyarados", item: "Iron Ball")])

      @p1.isImmune("Ground").should.be.false

  describe "Leppa Berry", ->
    it "restores 10 PP when the user reaches 0 PP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @p1
      move = pokemon.moves[0]
      pokemon.setPP(move, 1)

      @controller.makeMove(@id1, move.name)
      @controller.makeMove(@id2, 'Splash')

      pokemon.pp(move).should.equal 10

    it "restores 10 PP to the first move with 0 PP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @p1
      for move in pokemon.moves
        pokemon.setPP(move, 0)
      secondMove  = pokemon.moves[1]
      pokemon.setPP(secondMove, 1)

      @controller.makeMove(@id1, secondMove.name)
      @controller.makeMove(@id2, 'Splash')

      pokemon.pp(pokemon.moves[0]).should.equal 10
      pokemon.pp(secondMove).should.equal 0

  it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Leppa Berry")]

      pokemon = @p1
      move = pokemon.moves[0]
      pokemon.setPP(move, 1)

      @controller.makeMove(@id1, move.name)
      @controller.makeMove(@id2, 'Splash')

      pokemon.hasItem().should.be.false

  describe "Focus Band", ->
    it "has a 10% chance to survive an attack", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Focus Band")]

      pokemon = @p1
      pokemon.currentHP = 1

      shared.biasRNG.call(this, "randInt", 'focus band', 0)

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Tackle")

      pokemon.currentHP.should.equal 1

    it "lets the pokemon faint otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Focus Band")]

      pokemon = @p1
      pokemon.currentHP = 1

      shared.biasRNG.call(this, "randInt", 'focus band', 1)

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Tackle")

      pokemon.isFainted().should.be.true

  describe "Binding Band", ->
    it "makes trapping moves deal 1/8 damage per turn, not 1/16", ->
      shared.create.call this,
        team1: [Factory("Magikarp", evs: {speed: 4}, item: "Binding Band")]

      @battle.performMove(@p1, @battle.getMove("Fire Spin"))
      maxHP = @p2.stat('hp')
      @p2.currentHP = maxHP

      @battle.endTurn()
      expected = maxHP - Math.floor(maxHP / 8)
      @p2.currentHP.should.equal expected

  describe "Red Card", ->
    it "drags a pokemon out if a damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      target = @team2.at(1)
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @team2.first().should.equal target

    it "cancels any future action of the pokemon", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      target = @team2.at(1)
      @battle.performMove(@p2, @battle.getMove("Volt Switch"))
      @team2.first().should.equal(target)
      should.not.exist @battle.requestFor(@p2)
      should.not.exist @battle.requestFor(@team2.first())

    it "destroys the Red Card after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.hasItem().should.be.false

    it "does not activate if KOed by the move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card"), Factory("Magikarp")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      @p1.currentHP = 1
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @team2.first().should.equal(@p2)

    it "does not activate if there is only one Pokemon left", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp")]

      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.hasItem().should.be.true

    it "does not activate if a non-damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp"), Factory("Abra")]

      target = @p2
      @battle.performMove(@p2, @battle.getMove("Will-O-Wisp"))
      @p1.hasItem().should.be.true
      @p2.should.equal target

    it "activates and is used up even if the forced switch is prevented", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Red Card")]
        team2: [Factory("Magikarp", ability: "Suction Cups"), Factory("Abra")]

      target = @p2
      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.hasItem().should.be.false
      @p2.should.equal target

  describe "Shell Bell", ->
    it "restores 1/8 of damage dealt to target", ->
      shared.create.call(this, team1: [Factory("Magikarp", item: "Shell Bell")])

      @p1.currentHP = startHP = 1

      @battle.performMove(@p1, @battle.getMove("Outrage"))
      damage = @p2.stat('hp') - @p2.currentHP
      @p1.currentHP.should.equal(startHP + Math.floor(damage / 8))

  describe "Sticky Barb", ->
    it "damages 1/8 of holder's HP each turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @battle.endTurn()
      hp = @p1.stat('hp')
      (hp - @p1.currentHP).should.equal Math.floor(hp / 8)

    it "attaches to the attacking pokemon on a contact move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @battle.performMove(@p2, @battle.getMove("Tackle"))
      @p1.hasItem().should.be.false
      @p2.hasItem("Sticky Barb").should.be.true

    it "does not attach to the attacking pokemon on non-contact moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]

      @battle.performMove(@p2, @battle.getMove("Aura Sphere"))
      @p1.hasItem("Sticky Barb").should.be.true
      @p2.hasItem().should.be.false

    it "does not attach if the attacker has an item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Sticky Barb")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @battle.performMove(@p2, @battle.getMove("Tackle"))

      @p1.hasItem("Sticky Barb").should.be.true
      @p2.hasItem("Leftovers").should.be.true

  describe "Destiny Knot", ->
    it "infatuates the enemy as well if the holder becomes attracted", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F", item: "Destiny Knot")]
        team2: [Factory("Magikarp", gender: "M")]

      @battle.performMove(@p2, @battle.getMove("Attract"))
      @p1.has(Attachment.Attract).should.be.true
      @p2.has(Attachment.Attract).should.be.true

    it "is one-time use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "F", item: "Destiny Knot")]
        team2: [Factory("Magikarp", gender: "M")]

      @battle.performMove(@p2, @battle.getMove("Attract"))
      @p1.hasItem().should.be.false

    it "what happens if both pokemon have Destiny Knot?"
    it "what happens if the target is already attracted?"

  describe "Custap Berry", ->
    it "bumps the holder to the front of its priority bracket", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @p1.currentHP = 1
      @p2.currentHP = 1

      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p1, @p2 ]

    it "is one-time use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @p1.currentHP = 1

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Splash")

      @p1.hasItem().should.be.false

    it "does not activate at 26% HP", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Custap Berry")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @p1.currentHP = Math.floor(@p1.currentHP / 4) + 1

      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p2, @p1 ]
      @p1.hasItem().should.be.true

    it "activates at 50% HP if the Pokemon has Gluttony"
    it "is not activated by Pursuit on a switching Pokemon"

  describe 'Lansat Berry', ->
    it "gives the owner a Focus Energy attachment", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Lansat Berry")]

      @p1.currentHP = Math.floor(@p1.currentHP / 4)
      @p1.update()
      @p1.has(Attachment.FocusEnergy).should.be.true

  describe "Micle Berry", ->
    it "gives the owner a 1.2x accuracy boost on their next move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Micle Berry")]

      @p1.currentHP = Math.floor(@p1.currentHP / 4)

      @controller.makeMove(@id1, "Tackle")
      @controller.makeMove(@id2, "Splash")

      @p1.has(Attachment.MicleBerry).should.be.true
      @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
        .should.equal Math.floor(@battle.getMove('Tackle').accuracy * 1.2)

    it "goes away after their next move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Micle Berry")]

      @p1.currentHP = Math.floor(@p1.currentHP / 4)

      @controller.makeMove(@id1, "Tackle")
      @controller.makeMove(@id2, "Splash")

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Splash")

      @p1.has(Attachment.MicleBerry).should.be.false

  testEvasionItem = (itemName, ratio=0.9) ->
    describe itemName, ->
      it "gives the owner a #{ratio}x accuracy reduction", ->
        shared.create.call this,
          team2: [Factory("Magikarp", item: itemName)]

        @controller.makeMove(@id1, "Tackle")
        @controller.makeMove(@id2, "Splash")

        @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
          .should.equal Math.floor(@battle.getMove('Tackle').accuracy * ratio)

      it "no longer reduces accuracy if item is knocked off", ->
        shared.create.call this,
          team2: [Factory("Magikarp", item: itemName)]

        @p2.removeItem()

        @controller.makeMove(@id1, "Tackle")
        @controller.makeMove(@id2, "Splash")

        @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
          .should.equal Math.floor(@battle.getMove('Tackle').accuracy)

  testEvasionItem "BrightPowder"
  testEvasionItem "Lax Incense"

  testDelayItem = (itemName) ->
    describe itemName, ->
      it "delays the user to be last in its priority bracket", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName, evs: {speed: 4})]
          team2: [Factory("Magikarp")]

        @battle.recordMove(@id1, @battle.getMove('Tackle'))
        @battle.recordMove(@id2, @battle.getMove('Tackle'))
        @battle.determineTurnOrder()
        pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
        pokemon.should.eql [ @p2, @p1 ]

  testDelayItem 'Full Incense'
  testDelayItem 'Lagging Tail'

  describe "Macho Brace", ->
    it "halves the owner's speed", ->
      shared.create.call(this)

      speed = @p1.stat('speed')
      @p1.setItem(Item.MachoBrace)
      @p1.stat('speed').should.equal Math.floor(speed / 2)

  describe "Eject Button", ->
    it "requests a switch immediately after being damaged", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      bench = @team1.getAliveBenchedPokemon()
      # This record move is necessary to get rid of the initial request.
      @battle.recordMove(@id1, @battle.getMove('Splash'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.performMove(@p2, @battle.getMove('Tackle'))

      request = @battle.requestFor(@p1)
      should.exist(request)
      request.should.have.property("switches")
      request.switches.should.eql bench.map((p) => @team1.indexOf(p))

    it "cancels whatever action the ejecter had", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      bench = @team1.getAliveBenchedPokemon()
      @battle.recordMove(@id1, @battle.getMove('Splash'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))

      should.exist(@battle.getAction(@p1))
      @battle.performMove(@p2, @battle.getMove('Tackle'))
      should.not.exist(@battle.getAction(@p1))

    it "destroys the Eject Button after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Tackle")

      @p1.hasItem().should.be.false

    # TODO: Eject Button will force the owner out, and prevent
    # the attacker from switching.
    it "prevents self-switching moves from switching"

    it "does not activate if there is only one Pokemon left", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button")]
        team2: [Factory("Magikarp")]

      @controller.makeMove(@id1, "Splash")
      @controller.makeMove(@id2, "Tackle")

      @p1.hasItem().should.be.true

    it "does not activate if a non-damaging move is used", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Eject Button"), Factory("Abra")]
        team2: [Factory("Magikarp")]

      @battle.recordMove(@id1, @battle.getMove('Splash'))
      @battle.recordMove(@id2, @battle.getMove('Will-O-Wisp'))
      @battle.performMove(@p2, @battle.getMove('Will-O-Wisp'))

      @p1.hasItem().should.be.true
      should.not.exist @battle.requestFor(@p1)

  describe "Mental Herb", ->
    for effectName in ['Attract','Taunt','Encore','Torment','Disable']
      it "removes the effect of #{effectName} on Pokemon#update", ->
        shared.create.call this,
          team1: [Factory("Magikarp", gender: "M", item: "Mental Herb")]
          team2: [Factory("Magikarp", gender: "F")]

        @battle.performMove(@p1, @battle.getMove("Splash"))

        pokemon = @p1
        attachment = Attachment[effectName]
        pokemon.has(attachment).should.be.false
        pokemon.attach(attachment, source: @p2)
        pokemon.has(attachment).should.be.true

        pokemon.update(@battle)

        pokemon.has(attachment).should.be.false

    it "disappears after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", item: "Mental Herb")]
        team2: [Factory("Magikarp", gender: "F")]

      @battle.performMove(@p1, @battle.getMove("Splash"))

      pokemon = @p1
      pokemon.attach(Attachment.Attract, source: @p2)
      pokemon.update(@battle)

      pokemon.hasItem().should.be.false

    it "gets rid of the first highest priority effect", ->
      shared.create.call this,
        team1: [Factory("Magikarp", gender: "M", item: "Mental Herb")]
        team2: [Factory("Magikarp", gender: "F")]

      @battle.performMove(@p1, @battle.getMove("Splash"))

      pokemon = @p1
      pokemon.attach(Attachment.Attract, source: @p2)
      pokemon.attach(Attachment.Torment, source: @p2)
      pokemon.update(@battle)

      pokemon.has(Attachment.Attract).should.be.false
      pokemon.has(Attachment.Torment).should.be.true

  describe "Quick Claw", ->
    it "has a 20% chance to bump the owner's priority", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Quick Claw")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      shared.biasRNG.call(this, "next", 'quick claw', .1)
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p1, @p2 ]

    it "has a 80% chance to do nothing", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Quick Claw")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      shared.biasRNG.call(this, "next", 'quick claw', .2)
      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))
      @battle.determineTurnOrder()
      pokemon = @battle.pokemonActions.map((o) -> o.pokemon)
      pokemon.should.eql [ @p2, @p1 ]

  testFlinchItem = (itemName) ->
    describe itemName, ->
      it "has a 10% chance to flinch a Pokemon", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        @battle.performMove(@p1, @battle.getMove('Tackle'))
        @p2.has(Attachment.Flinch).should.be.true

      it "has a 20% chance to flinch with Serene Grace", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', .1)
        @battle.performMove(@p1, @battle.getMove('Tackle'))
        @p2.has(Attachment.Flinch).should.be.false

        @p1.copyAbility(Ability.SereneGrace)
        @battle.performMove(@p1, @battle.getMove('Tackle'))
        @p2.has(Attachment.Flinch).should.be.true

      it "has a 90% chance to do nothing", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0.1)
        @battle.performMove(@p1, @battle.getMove('Tackle'))
        @p2.has(Attachment.Flinch).should.be.false

      it "can't flinch if the move used can already flinch", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        shared.biasRNG.call(this, "next", 'secondary effect', 1)
        @battle.performMove(@p1, @battle.getMove('Headbutt'))
        @p2.has(Attachment.Flinch).should.be.false

      it "can't flinch if the move is non-damaging", ->
        shared.create.call this,
          team1: [Factory("Magikarp", item: itemName)]

        shared.biasRNG.call(this, "next", 'flinch item chance', 0)
        @battle.performMove(@p1, @battle.getMove('Glare'))
        @p2.has(Attachment.Flinch).should.be.false

  testFlinchItem "King's Rock"
  testFlinchItem "Razor Fang"

  describe "Zoom Lens", ->
    it "multiplies accuracy by 120% if target is moving after", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Zoom Lens", evs: {speed: 4})]
        team2: [Factory("Magikarp")]

      @battle.recordMove(@id1, @battle.getMove('Tackle'))
      @battle.recordMove(@id2, @battle.getMove('Tackle'))

      @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
        .should.equal Math.floor(@battle.getMove('Tackle').accuracy * 1.2)

    it "doesn't change accuracy if target will not move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Zoom Lens")]
        team2: [Factory("Magikarp", evs: {speed: 4})]

      @battle.recordMove(@id1, @battle.getMove('Tackle'))

      @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
        .should.equal Math.floor(@battle.getMove('Tackle').accuracy)

  describe "Wide Lens", ->
    it "boosts accuracy by 110%", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Wide Lens")]

      @battle.getMove('Tackle').chanceToHit(@battle, @p1, @p2)
        .should.equal Math.floor(@battle.getMove('Tackle').accuracy * 1.1)

  describe "Metronome", ->
    it "has a base power of x1.0 the first time a Pokemon uses a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Metronome")]

      modifier = @battle.getMove("Tackle").modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1000

    it "has a base power of x1.2 the second time a Pokemon uses a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Metronome")]

      @battle.performMove(@p1, @battle.getMove('Tackle'))

      modifier = @battle.getMove("Tackle").modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1333

    it "has a base power of x2.0 the sixth time a Pokemon uses a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Metronome")]

      for i in [1..5]
        @battle.performMove(@p1, @battle.getMove('Tackle'))

      modifier = @battle.getMove("Tackle").modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1FFF

    it "has a base power of x2.0 further times a Pokemon uses a move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Metronome")]

      for i in [1..6]
        @battle.performMove(@p1, @battle.getMove('Tackle'))

      modifier = @battle.getMove("Tackle").modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1FFF

    it "resets base power multiplier to x1.0 on a different move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Metronome")]
      tackle = @battle.getMove('Tackle')
      splash = @battle.getMove('Splash')

      @battle.performMove(@p1, tackle)
      @battle.performMove(@p1, splash)

      modifier = splash.modifyBasePower(@battle, @p1, @p2)
      modifier.should.equal 0x1000

  describe "Shed Shell", ->
    it "prevents blocking switches", ->
      pokemon = new Pokemon(item: "Shed Shell")
      pokemon.blockSwitch()
      pokemon.isSwitchBlocked().should.be.false

  describe "Big Root", ->
    it "boosts draining move recovery", ->
      shared.create.call this,
        team1: [Factory('Conkeldurr', item: "Big Root")]
        team2: [Factory('Hitmonchan')]
      startHP = 1
      @p1.currentHP = startHP
      hp = @p2.currentHP
      @battle.performMove(@p1, @battle.getMove('Drain Punch'))
      damage = (hp - @p2.currentHP)
      amount = util.roundHalfDown(Math.floor(damage / 2) * 1.3)
      (@p1.currentHP - startHP).should.equal(amount)

    it "boosts Leech Seed recovery, but not damage", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Big Root")]
      @p1.currentHP = startHP = 1
      targetAmount = (@p2.stat('hp') >> 3)
      userAmount = util.roundHalfDown(targetAmount * 1.3)

      @battle.performMove(@p1, @battle.getMove('Leech Seed'))
      @battle.endTurn()
      (@p1.currentHP - startHP).should.equal(userAmount)
      (@p2.stat('hp') - @p2.currentHP).should.equal(targetAmount)

    it "boosts Ingrain recovery", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Big Root")]
      @p1.currentHP = startHP = 1
      amount = util.roundHalfDown((@p1.stat('hp') >> 4) * 1.3)

      @battle.performMove(@p1, @battle.getMove('Ingrain'))
      @battle.endTurn()
      (@p1.currentHP - startHP).should.equal(amount)

    it "boosts Aqua Ring recovery", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: "Big Root")]
      @p1.currentHP = startHP = 1
      amount = util.roundHalfDown((@p1.stat('hp') >> 4) * 1.3)

      @battle.performMove(@p1, @battle.getMove('Aqua Ring'))
      @battle.endTurn()
      (@p1.currentHP - startHP).should.equal(amount)

  describe "Light Clay", ->
    it "boosts the Reflect/Light Screen turns to 8", ->
      shared.create.call(this, team1: [Factory('Magikarp', item: "Light Clay")])

      @battle.performMove(@p1, @battle.getMove('Reflect'))

      for i in [1..8]
        @team1.has(Attachment.Reflect).should.be.true
        @battle.endTurn()
      @team1.has(Attachment.Reflect).should.be.false

  describe "Eviolite", ->
    it "boosts defense and special defense by 50% if holder can evolve", ->
      shared.create.call(this, team1: [Factory('Magikarp')])
      defense = @p1.stat('defense')
      specialDefense = @p1.stat('specialDefense')
      @p1.setItem(Item.Eviolite)
      @p1.stat('defense').should.equal Math.floor(1.5 * defense)
      @p1.stat('specialDefense').should.equal Math.floor(1.5 * specialDefense)

    it "boosts nothing if holder cannot evolve", ->
      shared.create.call(this, team1: [Factory('Mew')])
      defense = @p1.stat('defense')
      @p1.setItem(Item.Eviolite)
      @p1.stat('defense').should.equal(defense)
      @p1.stat('specialDefense').should.equal(defense)

  describe "Expert Belt", ->
    it "boosts attacks by x1.2 if super-effective, x1.0 otherwise", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Expert Belt")]
        team2: [Factory("Magikarp")]
      tackle = @battle.getMove("Tackle")
      thunder = @battle.getMove("Thunder")
      tackle.modifyAttack(@battle, @p1, @p2).should.equal(0x1000)
      thunder.modifyAttack(@battle, @p1, @p2).should.equal(0x1333)
