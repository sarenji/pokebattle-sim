require './helpers'

should = require 'should'
{BattleQueue} = require('../server/queue')
db = require('../server/database')
ratings = require('../server/ratings')

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue().queue.should.be.empty

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue()
      queue.add(id: 'derp', {})
      queue.queue.should.have.length 1

    it 'queues two players', ->
      queue = new BattleQueue()
      queue.add(id: 'batman', {})
      queue.add(id: 'superman', {})
      queue.queue.should.have.length 2

    it 'cannot queue the same player twice', ->
      queue = new BattleQueue()
      queue.add(id: 'batman', {})
      queue.add(id: 'batman', {})
      queue.queue.should.have.length 1

    it 'cannot queue falsy references', ->
      queue = new BattleQueue()
      queue.add(null, {})
      queue.add(false, {})
      queue.add(undefined, {})
      queue.queue.should.have.length 0

  describe '#remove', ->
    it 'can dequeue old players', ->
      queue = new BattleQueue()
      player = {id: 'abc'}
      queue.add(player, {})
      queue.remove(player)
      queue.size().should.equal 0

    it "can take an array of players", ->
      queue = new BattleQueue()
      player1 = {id: 'abc'}
      player2 = {id: 'def'}
      queue.add(player1, {})
      queue.add(player2, {})
      queue.remove([ player1, player2 ])
      queue.queue.should.have.length 0

  describe '#queuedPlayers', ->
    it 'returns the players who are queued', ->
      queue = new BattleQueue()
      dude = {id: 'dude'}
      queue.add(dude)
      queue.queuedPlayers().should.includeEql dude
      queue.queuedPlayers().should.have.length 1

  describe '#pairPlayers', ->
    afterEach (done) ->
      db.flushdb(done)

    it 'takes players out of the queue', (done) ->
      queue = new BattleQueue()
      queue.add(id: 'batman')
      queue.add(id: 'superman')
      queue.pairPlayers ->
        queue.queuedPlayers().should.be.empty
        done()

    it 'leaves one person out if the queue length is odd', (done) ->
      queue = new BattleQueue()
      queue.add(id: 'batman')
      queue.add(id: 'superman')
      queue.add(id: 'flash')
      queue.pairPlayers ->
        queue.queuedPlayers().should.have.length 1
        done()

    it 'returns an array of pairs', (done) ->
      queue = new BattleQueue()
      queue.add(id: 'batman')
      queue.add(id: 'superman')
      queue.add(id: 'flash')
      queue.add(id: 'spiderman')
      queue.pairPlayers (err, results) ->
        should.not.exist(err)
        should.exist(results)
        results.should.be.instanceOf(Array)
        results.should.have.length(2)
        done()

    it "returns an array of pairs in the order of their rating", (done) ->
      args = []
      createPlayer = (rating) ->
        player = ratings.algorithm.createPlayer()
        player.rating = rating
        JSON.stringify(player)
      args.push("batman", createPlayer(1))
      args.push("superman", createPlayer(4))
      args.push("flash", createPlayer(3))
      args.push("spiderman", createPlayer(2))
      db.hmset("ratings", args...)
      queue = new BattleQueue()
      queue.add(id: 'batman')
      queue.add(id: 'superman')
      queue.add(id: 'flash')
      queue.add(id: 'spiderman')
      queue.pairPlayers (err, results) ->
        should.not.exist(err)
        should.exist(results)
        results.should.be.instanceOf(Array)
        results.should.have.length(2)
        results = results.map (result) ->
          result.map (p) -> p.player.id
        results.should.eql [[ "batman", "spiderman" ]
                            [ "flash", "superman"   ]]
        done()
