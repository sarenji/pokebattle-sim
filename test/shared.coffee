{Battle, BattleController} = require('../').server
{Factory} = require './factory'

shouldDoNoDamage = (moveName, battleOptions) ->
  it 'does no damage', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    @battle.performMove(@id1, move)
    @p2.currentHP.should.equal @p2.stat('hp')

shouldFailIfUsedTwice = (moveName, battleOptions) ->
  it 'should fail if used twice', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    mock = @sandbox.mock(move)
    mock.expects('fail').once()

    @battle.performMove(@id1, move)
    @battle.performMove(@id1, move)

    mock.verify()

build = (context, opts={}) ->
  context.id1 = 'abcde'
  context.id2 = 'fghij'
  context.player1 = opts.player1 || {id: context.id1, send: ->}
  context.player2 = opts.player2 || {id: context.id2, send: ->}
  team1   = opts.team1 || [Factory('Magikarp')]
  team2   = opts.team2 || [Factory('Magikarp')]
  players = [{player: context.player1, team: team1},
             {player: context.player2, team: team2}]
  numActive = opts.numActive || 1
  context.battle = new Battle('id', {players, numActive})
  context.controller = new BattleController(context.battle)
  context.team1  = context.battle.getTeam(context.player1.id)
  context.team2  = context.battle.getTeam(context.player2.id)
  context.p1 = context.team1.first()
  context.p2 = context.team2.first()

  createTestRNG.call(context)
  biasRNG.call(context, 'next', 'ch', 1)
  biasRNG.call(context, 'randInt', 'damage roll', 0)
  biasRNG.call(context, 'randInt', 'miss', 0)  # Can be overridden, of course.
  biasRNG.call(context, 'next', 'secondary status', 1)  # Often used in tests.

create = (opts={}) ->
  build(this, opts)
  @controller.beginBattle()

createTestRNG = ->
  @biasedRNGFuncs = {}
  for funcName in ['next', 'randInt']
    do (funcName) =>
      oldFunc = @battle.rng[funcName].bind(@battle.rng)
      @battle.rng[funcName] = (args...) =>
        id = args[args.length - 1]
        func = @biasedRNGFuncs[funcName]
        return (if id of func then func[id] else oldFunc(args...))

biasRNG = (funcName, id, returns) ->
  @biasedRNGFuncs[funcName] ||= {}
  @biasedRNGFuncs[funcName][id] = returns

module.exports = {shouldDoNoDamage, shouldFailIfUsedTwice, build, create, biasRNG}
