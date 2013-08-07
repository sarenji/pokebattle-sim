{BattleServer, Player} = require('../').server
{Factory} = require './factory'

require './helpers'

describe 'BattleServer', ->
  it 'can create a new battle', ->
    server = new BattleServer()
    battleId = server.createBattle()
    server.battles.should.have.ownProperty battleId

  it "sends the 'start battle' event for each matched player", ->
    players = [{id: 'abc', send: ->}, {id: 'def', send: ->}]
    spies = []
    for player in players
      spy = @sandbox.spy(player, 'send')
      spies.push(spy)

    server = new BattleServer()
    for player in players
      server.queuePlayer(player, [Factory('Hitmonchan')])
    server.beginBattles()

    for spy in spies
      spy.calledWith('start battle').should.be.true

  describe "#queuePlayer", ->
    it "queues players", ->
      server = new BattleServer()
      server.queuePlayer(id: "derp", [])
      server.queue.size().should.equal(1)

    it "does not queue null players", ->
      server = new BattleServer()
      server.queuePlayer(null, [])
      server.queue.size().should.equal(0)

    it "does not queue non-logged in players", ->
      server = new BattleServer()
      server.queuePlayer({}, [])
      server.queue.size().should.equal(0)

    it "does not queue players already queued", ->
      server = new BattleServer()
      server.queuePlayer(id: "derp", [])
      server.queuePlayer(id: "derp", [])
      server.queue.size().should.equal(1)

    it "does not queue invalid teams"
