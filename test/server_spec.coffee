sinon = require 'sinon'
{BattleServer, Player} = require('../').server

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer
    battleId = server.createBattle()
    server.battles.should.have.ownProperty battleId

  it "emits the 'start battle' event for each matched player", ->
    players = [{clientId: 'abc', emit: ->},
               {clientId: 'def', emit: ->}]
    mocks = []
    for player in players
      mock = sinon.mock(player)
      mock.expects('emit').once()
      mocks.push(mock)

    server = new BattleServer()
    for player in players
      server.queuePlayer(player, [])
    server.beginBattles()

    for mock in mocks
      mock.verify()
