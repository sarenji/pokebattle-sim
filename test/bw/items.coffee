sinon = require 'sinon'
{items, moves} = require('../../data/bw')
{attackStatModifier} = require '../../server/modifiers'
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
