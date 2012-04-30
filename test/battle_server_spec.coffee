{BattleServer} = require('../').server
sinon = require 'sinon'

describe 'BattleServer', ->
  describe '#queuePlayer', ->
    it "adds a new player to the server's queue", ->
      server = new BattleServer()
      server.queuePlayer({})
      server.queuedPlayers().should.have.length 1

  describe '#beginBattles', ->
    it 'tells the engine to create battles', ->
      server = new BattleServer()
      stub = sinon.stub(server, 'createBattle')
      server.queuePlayer({})
      server.queuePlayer({})
      server.beginBattles()
      stub.called.should.be.true

    it 'emits the "start battle" event for each player', ->
      server = new BattleServer()
      player = { emit: -> }
      sinon.stub(server, 'createBattle')
      mock = sinon.mock(player)
      mock.expects('emit').twice().withArgs('start battle')

      server.queuePlayer(player)
      server.queuePlayer(player)
      server.beginBattles()
      mock.verify()
