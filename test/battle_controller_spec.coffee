{moves} = require('../data/bw')
{Battle, Pokemon, Status, VolatileStatus, Attachment} = require('../').server
{Factory} = require './factory'
should = require 'should'
shared = require './shared'
itemTests = require './bw/items'
moveTests = require './bw/moves'

describe 'BattleController', ->
  it "automatically ends the turn if all players move", ->
    shared.create.call(this)
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeMove(@player1, 'Tackle')
    @controller.makeMove(@player2, 'Tackle')
    mock.verify()

  it "automatically ends the turn if all players switch", ->
    shared.create.call this,
      team1: [Factory('Hitmonchan'), Factory('Heracross')]
      team2: [Factory('Hitmonchan'), Factory('Heracross')]
    mock = @sandbox.mock(@controller)
    mock.expects('continueTurn').once()
    @controller.makeSwitch(@player1, 1)
    @controller.makeSwitch(@player2, 1)
    mock.verify()
