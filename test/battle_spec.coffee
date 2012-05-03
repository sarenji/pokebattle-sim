sinon = require 'sinon'
{Battle, Pokemon} = require('../').server

describe 'Battle', ->
  beforeEach ->
    @player1 = {clientId: 'abcde'}
    @player2 = {clientId: 'fghij'}
    team1   = [{}, {}]
    team2   = [{}, {}]
    players = [{player: @player1, team: team1},
               {player: @player2, team: team2}]
    @battle = new Battle(players: players)
    @team1  = @battle.getTeam(@player1.clientId)
    @team2  = @battle.getTeam(@player2.clientId)

  it 'starts at turn 0', ->
    @battle.turn.should.equal 0

  describe '#hasAllPlayersActed', ->
    it "returns false if no player has moved", ->
      @battle.hasAllPlayersActed().should.be.false

    it "returns false if half the players have not moved", ->
      @battle.playerActions[@player1.clientId] = true
      @battle.hasAllPlayersActed().should.be.false

    it "returns true if all players have moved", ->
      @battle.playerActions[@player1.clientId] = true
      @battle.playerActions[@player2.clientId] = true
      @battle.hasAllPlayersActed().should.be.true

  describe '#makeMove', ->
    it "records a player's move", ->
      @battle.makeMove(@player1, 'Tackle')
      @battle.playerActions.should.have.property @player1.clientId
      @battle.playerActions[@player1.clientId].name.should.equal 'tackle'

    # TODO: Invalid moves should fail in some way.
    it "doesn't record invalid moves", ->
      @battle.makeMove(@player1, 'Blooberry Gun')
      @battle.playerActions.should.not.have.property @player1.clientId

    it "automatically ends the turn if all players move", ->
      mock = sinon.mock(@battle)
      mock.expects('endTurn').once()
      @battle.makeMove(@player1, 'Tackle')
      @battle.makeMove(@player2, 'Tackle')
      mock.verify()

  describe '#switch', ->
    it "swaps pokemon positions of a player's team", ->
      [poke1, poke2] = @team1
      @battle.switch(@player1, 1)
      @battle.endTurn()
      @team1.slice(0, 2).should.eql [poke2, poke1]

    it "automatically ends the turn if all players switch", ->
      mock = sinon.mock(@battle)
      mock.expects('endTurn').once()
      @battle.switch(@player1, 1)
      @battle.switch(@player2, 1)
      mock.verify()

  describe '#endTurn', ->
    it "makes pokemon use move", ->
      defender = @team2[0]
      hp = defender.currentHP
      @battle.makeMove(@player1, 'Tackle')
      @battle.endTurn()
      defender.currentHP.should.be.lessThan hp

  describe "#damage", ->
    it "reduces the pokemon's hp", ->
      @battle.damage(@team1[0], @team2[0], 3)
      @team2[0].currentHP.should.equal 338
