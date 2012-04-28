{BattleServer} = require '../server'

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer
    battleId = server.createBattle()
    server.battles.hasOwnProperty(battleId).should.equal true
