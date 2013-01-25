sinon = require 'sinon'
{Battle} = require('../').server
{Factory} = require './factory'

shouldDoNoDamage = (name, battleOptions) ->
  it 'does no damage', ->
    create.call(this, battleOptions)
    @battle.makeMove(@player1, name)
    @battle.makeMove(@player2, 'Splash')
    @team2.at(0).currentHP.should.equal @team2.at(0).stat('hp')

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
  @nextStub = sinon.stub(@battle.rng, 'next')
  @nextStub.withArgs("ch").returns(1) # no chs
  @intStub = sinon.stub(@battle.rng, 'randInt')
  # always max damage
  @intStub.withArgs(sinon.match.any, sinon.match.any, "damage roll").returns(0)
  @team1  = @battle.getTeam(@player1.id)
  @team2  = @battle.getTeam(@player2.id)

module.exports = {shouldDoNoDamage, create}
