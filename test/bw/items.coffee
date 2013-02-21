sinon = require 'sinon'
{items, moves} = require('../../data/bw')
{attackStatModifier} = require '../../server/modifiers'
{Status} = require '../../server/status'
{Factory} = require '../factory'
should = require 'should'
{_} = require 'underscore'
shared = require '../shared'

@test = ->
  describe "leftovers", ->
    it "heals 1/16 of a pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Leftovers')]
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')
      amount = Math.floor(@team1.at(0).stat('hp') / 16)
      @team1.at(0).currentHP.should.equal(1 + amount)

  describe "Black Sludge", ->
    it "heals 1/16 of a poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Weezing', item: 'Black Sludge')]
      @team1.at(0).currentHP = 1
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')
      amount = Math.floor(@team1.at(0).stat('hp') / 16)
      @team1.at(0).currentHP.should.equal(1 + amount)

    it "damages 1/16 of a non-poison pokemon's HP at the end of a turn", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Black Sludge')]
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')
      fullHP = @team1.at(0).stat('hp')
      amount = Math.floor(fullHP / 16)
      (fullHP - @team1.at(0).currentHP).should.equal(amount)

  describe "muscle band", ->
    it "increases base power of physical moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199

      move = moves['shadow-ball']
      modifier = items['Muscle Band'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "Wise Glasses", ->
    it "increases base power of special moves by 0x1199", ->
      shared.create.call(this)
      move = moves['tackle']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

      move = moves['shadow-ball']
      modifier = items['Wise Glasses'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1199

  describe "An Orb item", ->
    it "increases base power of moves matching the user's type by 0x1333", ->
      shared.create.call this,
        team1: [Factory('Giratina (origin)')]
      move = moves['outrage']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

      move = moves['shadow-ball']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

      move = moves['tackle']
      modifier = items['Griseous Orb'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "A type-boosting miscellaneous item", ->
    it "increases base power of certain typed moves by 0x1333", ->
      shared.create.call(this)
      move = moves['outrage']
      modifier = items['Odd Incense'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

      move = moves['psychic']
      modifier = items['Odd Incense'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1333

  describe "A typed Gem", ->
    it "increases base power of certain typed moves by 0x1800", ->
      shared.create.call(this)
      move = moves['acrobatics']
      modifier = items['Flying Gem'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1800

      move = moves['psychic']
      modifier = items['Flying Gem'].basePowerModifier(move, @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

    it "is removed after use", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @battle.makeMove(@player1, 'Acrobatics')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team1.at(0).item

    it "is not removed after use if the move isn't the right type", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'Flying Gem')]
      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      should.exist @team1.at(0).item

  describe "A typed plate", ->
    it "has the plate attribute set", ->
      item = items['Draco Plate']
      item.should.have.property('plate')

    it "changes the Arceus type"

  describe "DeepSeaTooth", ->
    it "doubles Clamperl's special attack", ->
      shared.create.call this,
        team1: [Factory('Clamperl', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['surf'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x2000

    it "doesn't double Clamperl's attack", ->
      shared.create.call this,
        team1: [Factory('Clamperl', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['tackle'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

    it "doesn't double non-Clamperl special attack", ->
      shared.create.call this,
        team1: [Factory('Magikarp', item: 'DeepSeaTooth')]
      modifier = attackStatModifier.run(moves['surf'], @battle, @team1.at(0), @team2.at(0))
      modifier.should.equal 0x1000

  describe "Rocky Helmet", ->
    it "deals 1/6 of the attacker's total HP on a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @team1.first().stat('hp')
      currentHP = @team1.first().currentHP = Math.floor(hp * 2 / 3)
      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal currentHP - Math.floor(hp / 6)

    it "doesn't deal damage back to attacker if not a contact move", ->
      shared.create.call this,
        team2: [Factory('Ferrothorn', item: 'Rocky Helmet')]

      hp = @team1.first().stat('hp')
      currentHP = @team1.first().currentHP = Math.floor(hp * 2 / 3)
      @battle.makeMove(@player1, 'Earthquake')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal currentHP

    it "stacks with each hit of multi-hit moves like Tail Slap"
    it "doesn't let certain effects activate if attacker faints"

  describe "Absorb Bulb", ->
    it "boosts the special attack of the target by 1 if hit by a water move", ->
      shared.create.call this,
        team2: [Factory("Ferrothorn", item: "Absorb Bulb")]
      @battle.makeMove(@player1, 'Water Gun')
      @battle.makeMove(@player2, 'Splash')

      @team2.first().stages.specialAttack.should.equal 1

    it "is one-time use", ->
      shared.create.call this,
        team2: [Factory("Ferrothorn", item: "Absorb Bulb")]
      @battle.makeMove(@player1, 'Water Gun')
      @battle.makeMove(@player2, 'Splash')

      should.not.exist @team2.first().item

    it "does not boost the special attack of the target by 1 if not hit by a water move", ->
      shared.create.call this,
        team2: [Factory("Ferrothorn", item: "Absorb Bulb")]
      @battle.makeMove(@player1, 'Ember')
      @battle.makeMove(@player2, 'Splash')

      @team2.first().stages.specialAttack.should.equal 0

  describe "Float Stone", ->
    it "halves the user's weight", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Float Stone")]

      weight = @team1.first().weight
      @team1.first().calculateWeight().should.equal Math.floor(weight / 2)

  describe "Focus Sash", ->
    it "always lets the user survive at 100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      item = items['Focus Sash']
      damage = item.editDamage(@battle, @team1.first(), moves['ember'], 99999)
      damage.should.equal @team2.first().currentHP - 1

    it "should not activate at <100% HP", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      @team1.first().currentHP--

      item = items['Focus Sash']
      damage = item.editDamage(@battle, @team1.first(), moves['ember'], 99999)
      damage.should.equal 99999

    it "disappears after activation", ->
      shared.create.call this,
        team2: [Factory("Magikarp", item: "Focus Sash")]

      stub = sinon.stub(moves['ember'], 'calculateDamage', -> 9999)

      @battle.makeMove(@player1, 'Ember')
      @battle.makeMove(@player2, 'Splash')

      stub.restore()
      @team2.first().hasItem().should.be.false

  describe "Choice items", ->
    it "locks the user into its first selected move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player1.id].moves
      requestedMoves.should.eql [ moves['splash'] ]

    it "does not lock the user if it moves after gaining the item", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band", evs: {speed:4})]

      @battle.makeMove(@player1, 'Trick')
      @battle.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player2.id].moves
      requestedMoves.should.eql [ moves['splash'], moves['tackle'] ]

    it "does not automatically lock the user when it switches back in", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Choice Band"), Factory("Magikarp")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @battle.makeSwitch(@player1, 1)
      @battle.makeMove(@player2, 'Splash')

      requestedMoves = @battle.requests[@player1.id].moves
      requestedMoves.should.eql [ moves['splash'], moves['tackle'] ]

    xit "relocks the pokemon after Magic Room"

  describe "Choice Scarf", ->
    it "increases the speed of the Pokemon by x1.5", ->
      shared.create.call(this)

      speed = @team1.first().stat('speed')
      @team1.first().setItem(@battle, items['Choice Scarf'])
      @team1.first().stat('speed').should.equal Math.floor(speed * 1.5)

  describe "Flame Orb", ->
    it "burns the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.BURN).should.be.true

    it "does not burn the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Flame Orb")]

      @team1.first().setStatus(Status.SLEEP)

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.BURN).should.be.false

  describe "Toxic Orb", ->
    it "toxics the user at the end of the turn", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.TOXIC).should.be.true

    it "does not toxic the user if it is already statused", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Toxic Orb")]

      @team1.first().setStatus(Status.SLEEP)

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasStatus(Status.TOXIC).should.be.false

  describe "Air Balloon", ->
    it "makes the user immune to ground moves", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      move = moves['earthquake']
      type = move.getType(@battle, @team1.first(), @team2.first())
      @team1.first().isImmune(@battle, type).should.be.true

    it "pops if hit by an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Tackle')

      @team1.first().hasItem().should.be.false

    it "does not pop if hit by a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Flatter')

      @team1.first().hasItem().should.be.true

    it "no longer makes the pokemon immune when popped", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Tackle')

      move = moves['earthquake']
      type = move.getType(@battle, @team1.first(), @team2.first())
      @team1.first().isImmune(@battle, type).should.be.false

    it "stops effecting a pokemon if Tricked away", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Air Balloon")]
        team2: [Factory("Magikarp", item: "Leftovers")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Trick')

      @team1.first().hasAttachment("AirBalloonAttachment").should.be.false
      @team2.first().hasAttachment("AirBalloonAttachment").should.be.true

  describe "White Herb", ->
    it "negates negative status boosts", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "White Herb")]

      @battle.makeMove(@player1, 'Shell Smash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().stages.should.include {
        attack: 2, defense: 0, speed: 2, specialAttack: 2, specialDefense: 0
      }

  describe "Life Orb", ->
    it "removes 10% from the pokemon's HP when using an attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Splash')

      hp = @team1.first().stat('hp')
      (hp - @team1.first().currentHP).should.equal Math.floor(hp / 10)

    it "doesn't remove 10% HP when using a non-attacking move", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Life Orb")]

      @battle.makeMove(@player1, 'Growl')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().currentHP.should.equal @team1.first().stat('hp')

  describe "Salac berry", ->
    it "raises the Pokemon's Speed when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().stages.speed.should.equal(0)

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().stages.speed.should.equal(1)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

  describe "Starf berry", ->
    it "sharply raises a random stat when HP falls at 25% or less", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().stages.defense.should.equal(2)

    it "is consumed after use", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Salac Berry")]

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      @team1.first().hasItem().should.be.false

    it "only raises stats that aren't at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      @team1.first().stages.defense = 6
      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      # Note: This depends on the stats array inside
      # the definition of Starf Berry. Not exactly robust.
      @team1.first().stages.specialAttack.should.equal(2)
      @team1.first().hasItem().should.be.false

    it "doesn't raise any stat if all main stats are at +6", ->
      shared.create.call this,
        team1: [Factory("Magikarp", item: "Starf Berry")]

      shared.biasRNG.call(this, "randInt", 'starf berry stat', 1)

      stats = ["attack", "defense", "specialAttack", "specialDefense", "speed"]
      for stat in stats
        @team1.first().stages[stat] = 6

      @team1.first().currentHP = Math.floor(@team1.first().currentHP / 4)
      @battle.makeMove(@player1, 'Splash')
      @battle.makeMove(@player2, 'Splash')

      hash = {}
      for stat in stats
        hash[stat] = 6
      @team1.first().stages.should.include(hash)
      @team1.first().hasItem().should.be.false

