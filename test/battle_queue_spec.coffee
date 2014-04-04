require './helpers'

should = require 'should'
{BattleQueue} = require('../server/queue')
db = require('../server/database')
ratings = require('../server/ratings')
db = require('../server/database')

describe 'BattleQueue', ->
  afterEach (done) ->
    db.flushdb(done)

  it 'should be empty by default', ->
    new BattleQueue().should.be.empty

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue()
      queue.add('derp', {})
      queue.should.have.length 1

    it 'queues two players', ->
      queue = new BattleQueue()
      queue.add('batman', {})
      queue.add('superman', {})
      queue.should.have.length 2

    it 'cannot queue the same player twice', ->
      queue = new BattleQueue()
      queue.add('batman', {})
      queue.add('batman', {})
      queue.should.have.length 1

    it 'cannot queue falsy references', ->
      queue = new BattleQueue()
      queue.add(null, {})
      queue.add(false, {})
      queue.add(undefined, {})
      queue.should.have.length 0

  describe '#remove', ->
    it 'can dequeue old players', ->
      queue = new BattleQueue()
      player = 'abc'
      queue.add(player, {})
      queue.remove(player)
      queue.size().should.equal 0

    it "can take an array of players", ->
      queue = new BattleQueue()
      player1 = 'abc'
      player2 = 'def'
      queue.add(player1, {})
      queue.add(player2, {})
      queue.remove([ player1, player2 ])
      queue.should.have.length 0

  describe '#queuedPlayers', ->
    it 'returns the players who are queued', ->
      queue = new BattleQueue()
      dude = 'dude'
      queue.add(dude)
      queue.queuedPlayers().should.includeEql(dude)
      queue.queuedPlayers().should.have.length 1

  describe '#pairPlayers', ->
    afterEach (done) ->
      db.flushdb(done)

    it 'takes players out of the queue', (done) ->
      queue = new BattleQueue()
      queue.add('batman')
      queue.add('superman')
      queue.pairPlayers ->
        queue.queuedPlayers().should.be.empty
        done()

    it 'leaves one person out if the queue length is odd', (done) ->
      queue = new BattleQueue()
      queue.add('batman')
      queue.add('superman')
      queue.add('flash')
      queue.pairPlayers ->
        queue.queuedPlayers().should.have.length 1
        done()

    it 'returns an array of pairs', (done) ->
      queue = new BattleQueue()
      queue.add('batman')
      queue.add('superman')
      queue.add('flash')
      queue.add('spiderman')
      queue.pairPlayers (err, results) ->
        should.not.exist(err)
        should.exist(results)
        results.should.be.instanceOf(Array)
        results.should.have.length(2)
        done()

    it "returns an array of pairs in the order of their rating", (done) ->
      ratings.setRating "batman", 1, ->
        ratings.setRating "superman", 4, ->
          ratings.setRating "flash", 3, ->
            ratings.setRating "spiderman", 2, ->
              queue = new BattleQueue()
              queue.add('batman')
              queue.add('superman')
              queue.add('flash')
              queue.add('spiderman')
              queue.pairPlayers (err, results) ->
                should.not.exist(err)
                should.exist(results)
                results.should.be.instanceOf(Array)
                results.should.have.length(2)
                results = results.map (result) ->
                  Object.keys(result)
                results.should.eql [[ "batman", "spiderman" ]
                                    [ "flash", "superman"   ]]
                done()
