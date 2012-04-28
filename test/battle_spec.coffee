{Battle} = require '../server/battle'

describe 'Battle', ->
  beforeEach ->
    @player1 = {clientId: 'abcde'}
    @player2 = {clientId: 'fghij'}
    @battle  = new Battle(players: [@player1, @player2])

  it 'starts at turn 0', ->
    @battle.turn.should.equal 0

  describe '#makeMove', ->
    it "records a player's move", ->
      @battle.makeMove(@player1, 'Tackle')
      @battle.playerMoves.should.have.property @player1.clientId
      @battle.playerMoves[@player1.clientId].should.equal 'Tackle'

    # TODO: Invalid moves should fail in some way.
    it "doesn't record invalid moves", ->
      @battle.makeMove(@player1, 'Blooberry Gun')
      @battle.playerMoves.should.not.have.property @player1.clientId
