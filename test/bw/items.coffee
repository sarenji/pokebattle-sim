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
