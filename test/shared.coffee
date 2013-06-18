{Battle, BattleController} = require('../').server
{Factory} = require './factory'

shouldDoNoDamage = (moveName, battleOptions) ->
  it 'does no damage', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    @battle.performMove(@id1, move)
    @team2.first().currentHP.should.equal @team2.first().stat('hp')

shouldFailIfUsedTwice = (moveName, battleOptions) ->
  it 'should fail if used twice', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    mock = @sandbox.mock(move)
    mock.expects('fail').once()

    @battle.performMove(@id1, move)
    @battle.performMove(@id1, move)

    mock.verify()

create = (opts={}) ->
  @id1 = 'abcde'
  @id2 = 'fghij'
  @player1 = opts.player1 || {id: @id1, emit: ->}
  @player2 = opts.player2 || {id: @id2, emit: ->}
  team1   = opts.team1 || [Factory('Magikarp')]
  team2   = opts.team2 || [Factory('Magikarp')]
  players = [{player: @player1, team: team1},
             {player: @player2, team: team2}]
  @battle = new Battle('id', players: players)
  @controller = new BattleController(@battle)
  @controller.beginBattle()
  @team1  = @battle.getTeam(@player1.id)
  @team2  = @battle.getTeam(@player2.id)

  createTestRNG.call(this)
  biasRNG.call(this, 'next', 'ch', 1)
  biasRNG.call(this, 'randInt', 'damage roll', 0)
  biasRNG.call(this, 'randInt', 'miss', 0)  # Can be overridden, of course.

createTestRNG = ->
  @biasedRNGFuncs = {}
  for funcName in ['next', 'randInt']
    do (funcName) =>
      oldFunc = @battle.rng[funcName]
      @battle.rng[funcName] = (args...) =>
        id = args[args.length - 1]
        func = @biasedRNGFuncs[funcName]
        return (if id of func then func[id] else oldFunc(args...))

biasRNG = (funcName, id, returns) ->
  @biasedRNGFuncs[funcName] ||= {}
  @biasedRNGFuncs[funcName][id] = returns

module.exports = {shouldDoNoDamage, shouldFailIfUsedTwice, create, biasRNG}
