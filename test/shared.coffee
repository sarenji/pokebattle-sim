{Factory} = require './factory'

shouldDoNoDamage = (moveName, battleOptions) ->
  it 'does no damage', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    @battle.performMove(@p1, move)
    @p2.currentHP.should.equal @p2.stat('hp')

shouldFailIfUsedTwice = (moveName, battleOptions) ->
  it 'should fail if used twice', ->
    create.call(this, battleOptions)
    move = @battle.getMove(moveName)
    mock = @sandbox.mock(move).expects('fail').once()

    @battle.performMove(@p1, move)
    @battle.performMove(@p1, move)

    mock.verify()

build = (context, opts={}) ->
  generation = opts.gen ? 'bw'
  {Battle} = require("../server/#{generation}/battle")
  {BattleController} = require("../server/#{generation}/battle_controller")
  context.id1 = 'abcde'
  context.id2 = 'fghij'
  team1   = opts.team1 || [Factory('Magikarp'), Factory('Magikarp')]
  team2   = opts.team2 || [Factory('Magikarp'), Factory('Magikarp')]
  conditions = opts.conditions
  players = [
    {id: context.id1, name: context.id1, team: team1, ratingKey: context.id1}
    {id: context.id2, name: context.id2, team: team2, ratingKey: context.id2}
  ]
  numActive = opts.numActive || 1
  context.battle = new Battle('id', players, {numActive, conditions})
  context.controller = new BattleController(context.battle)
  context.team1  = context.battle.getTeam(context.id1)
  context.team2  = context.battle.getTeam(context.id2)
  context.p1 = context.team1.first()
  context.p2 = context.team2.first()

  createTestRNG.call(context)
  biasRNG.call(context, 'next', 'ch', 1)
  biasRNG.call(context, 'randInt', 'damage roll', 0)
  biasRNG.call(context, 'randInt', 'miss', 0)  # Can be overridden, of course.
  biasRNG.call(context, 'next', 'secondary effect', 1)  # No effect unless 100%
  biasRNG.call(context, 'next', 'secondary boost', 0)  # Always happens
  biasRNG.call(context, 'randInt', 'flinch', 99)  # No flinch (unless fake out)
  # moves that call other moves also get new targets
  biasRNG.call(context, 'randInt', 'selected pokemon target', 0)

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

testEveryMove = (allMoves, gen) ->
  for move in allMoves
    if move.hasPrimaryEffect()
      do (move) ->
        describe move.name, ->
          # Test primary boost moves
          if move.primaryBoostStats?
            it "boosts properly", ->
              create.call(this, gen: gen)
              target = (if move.primaryBoostTarget == 'self' then @p1 else @p2)
              target.stages.should.not.include(move.primaryBoostStats)
              @battle.performMove(@p1, move)
              target.stages.should.include(move.primaryBoostStats)

            if move.primaryBoostTarget == 'self'
              it "can never miss self", ->
                create.call(this, gen: gen)
                move.chanceToHit(@battle, @p1, @p1).should.equal(0)

biasRNG = (funcName, id, returns) ->
  @biasedRNGFuncs[funcName] ||= {}
  @biasedRNGFuncs[funcName][id] = returns

module.exports = {
  shouldDoNoDamage, shouldFailIfUsedTwice,
  build, create, biasRNG, testEveryMove
}
