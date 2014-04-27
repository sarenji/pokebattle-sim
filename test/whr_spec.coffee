{WHR} = require('../server/whr')

describe 'WHR', ->
  beforeEach ->
    @whr = whr = new WHR()
    @createGameWithElo = (whiteRating, blackRating, handicap = 0) ->
      game = whr.createGame("black", "white", "W", 1, handicap)
      game.blackPlayer.days[0].elo(blackRating)
      game.whitePlayer.days[0].elo(whiteRating)
      game

  it 'should have a 50% winrate for a game between equal-strength players', ->
    game = @createGameWithElo(500, 500, 0)
    Math.abs(game.whiteWinProbability() - 0.5).should.be.lessThan(0.0001)

  it 'should confer advantage to handicap', ->
    game = @createGameWithElo(500, 500, 1)
    game.blackWinProbability().should.be.greaterThan(0.5)

  it 'should confer advantage to higher rank', ->
    game = @createGameWithElo(600, 500, 0)
    game.whiteWinProbability().should.be.greaterThan(0.5)

  it 'should confer advantage to higher rank', ->
    game = @createGameWithElo(600, 500, 0)
    game.whiteWinProbability().should.be.greaterThan(0.5)

  it 'should grant same winrate to same elo differences', ->
    game1 = @createGameWithElo(100, 200, 0)
    game2 = @createGameWithElo(200, 300, 0)
    abs = Math.abs(game1.whiteWinProbability() - game2.whiteWinProbability())
    abs.should.be.lessThan(0.0001)

  it 'should grant correct winrate to a twice-as-strong player', ->
    game = @createGameWithElo(100, 200, 0)
    abs = Math.abs(0.359935 - game.whiteWinProbability())
    abs.should.be.lessThan(0.000001)

  it 'should make winrates inversely proportional with unequal ranks', ->
    game = @createGameWithElo(600, 500, 0)
    abs = Math.abs(game.whiteWinProbability() + game.blackWinProbability())
    (1 - abs).should.be.lessThan(0.0001)

  
  it 'should make winrates inversely proportional with handicap', ->
    game = @createGameWithElo(500, 500, 4)
    abs = Math.abs(game.whiteWinProbability() + game.blackWinProbability())
    (1 - abs).should.be.lessThan(0.0001)
    
  it 'should return the proper output on iteration', ->
    @whr.createGame("shusaku", "shusai", "B", 1, 0)
    @whr.createGame("shusaku", "shusai", "W", 2, 0)
    @whr.createGame("shusaku", "shusai", "W", 3, 0)
    @whr.createGame("shusaku", "shusai", "W", 4, 0)
    @whr.createGame("shusaku", "shusai", "W", 4, 0)
    @whr.iterate(50)
    @whr.ratingsForPlayer("shusaku").should.eql([[1, -92, 71], [2, -94, 71], [3, -95, 71], [4, -96, 72]])
    @whr.ratingsForPlayer("shusai").should.eql([[1, 92, 71], [2, 94, 71], [3, 95, 71], [4, 96, 72]])
  
  it 'should raise an unstable rating exception in certain cases', ->
    for x in [1..10]
      @whr.createGame("anchor", "player", "B", 1, 0)
      @whr.createGame("anchor", "player", "W", 1, 0)

    for x in [1..10]
      @whr.createGame("anchor", "player", "B", 180, 600)
      @whr.createGame("anchor", "player", "W", 180, 600)

    (=> @whr.iterate(10)).should.throw(WHR.UnstableRatingException)
