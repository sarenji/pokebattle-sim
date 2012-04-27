{BattleServer} = require '../server'
{Engine} = require '../engine'
sinon = require 'sinon'

describe 'BattleServer', ->
  describe '#queuePlayer', ->
    it "adds a new player to the server's queue", ->
      server = new BattleServer()
      server.queuePlayer({})
      server.queuedPlayers().should.have.length 1

  describe '#beginBattles', ->
    it 'tells the engine to create battles', ->
      engine = new Engine()
      server = new BattleServer(engine)
      stub = sinon.stub(engine, 'createBattle')
      server.queuePlayer({})
      server.queuePlayer({})
      server.beginBattles()
      stub.called.should.be.true

    it 'emits the "start battle" event for each player', ->
      engine = new Engine()
      server = new BattleServer(engine)
      player = { emit: -> }
      sinon.stub(engine, 'createBattle')
      mock = sinon.mock(player)
      mock.expects('emit').twice().withArgs('start battle')

      server.queuePlayer(player)
      server.queuePlayer(player)
      server.beginBattles()
      mock.verify()
