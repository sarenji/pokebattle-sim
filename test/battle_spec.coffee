sinon = require 'sinon'
{Battle} = require '../server/battle'
{Pokemon} = require '../server/pokemon'

describe 'Battle', ->
  beforeEach ->
    @player1 = {clientId: 'abcde', team: [{}, {}]}
    @player2 = {clientId: 'fghij', team: [{}, {}]}
    @battle  = new Battle(players: [@player1, @player2])

  it 'starts at turn 0', ->
    @battle.turn.should.equal 0

  describe '#hasAllPlayersMoved', ->
    it "returns false if no player has moved", ->
      @battle.hasAllPlayersMoved().should.be.false

    it "returns false if half the players have not moved", ->
      @battle.playerMoves[@player1.clientId] = true
      @battle.hasAllPlayersMoved().should.be.false

    it "returns true if all players have moved", ->
      @battle.playerMoves[@player1.clientId] = true
      @battle.playerMoves[@player2.clientId] = true
      @battle.hasAllPlayersMoved().should.be.true

  describe '#makeMove', ->
    it "records a player's move", ->
      @battle.makeMove(@player1, 'Tackle')
      @battle.playerMoves.should.have.property @player1.clientId
      @battle.playerMoves[@player1.clientId].name.should.equal 'tackle'

    # TODO: Invalid moves should fail in some way.
    it "doesn't record invalid moves", ->
      @battle.makeMove(@player1, 'Blooberry Gun')
      @battle.playerMoves.should.not.have.property @player1.clientId

    it "automatically ends the turn if all players move", ->
      mock = sinon.mock(@battle)
      mock.expects('endTurn').once()
      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Tackle')
      mock.verify()

  describe '#switch', ->
    it "swaps pokemon positions of a player's team", ->
      [poke1, poke2] = @player1.team
      @battle.switch(@player1, 1)
      @battle.endTurn()
      @player1.team.slice(0, 2).should.eql [poke2, poke1]

    it "automatically ends the turn if all players switch", ->
      mock = sinon.mock(@battle)
      mock.expects('endTurn').once()
      @battle.switch(@player1, 1)
      @battle.switch(@player2, 1)
      mock.verify()

  describe '#endTurn', ->
    it "makes pokemon use move", ->
      defender = @player2.team[0]
      hp = defender.currentHP
      @battle.makeMove(@player1, 'Tackle')
      @battle.endTurn()
      defender.currentHP.should.be.lessThan hp

  describe "#damage", ->
    it "reduces the pokemon's hp", ->
      @battle.damage(@player1.team[0], @player2.team[0], 3)
      @player2.team[0].currentHP.should.equal 338
