require './helpers'

should = require 'should'
async = require 'async'
{BattleQueue} = require('../server/queue')
redis = require('../server/redis')
ratings = require('../server/ratings')
db = require('../server/database')
alts = require('../server/alts')
async = require('async')

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue().should.be.empty

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue()
      queue.add('derp', 'derp', {})
      queue.should.have.length 1

    it 'queues two players', ->
      queue = new BattleQueue()
      queue.add('batman', 'batman', {})
      queue.add('superman', 'superman', {})
      queue.should.have.length 2

    it 'cannot queue the same player twice', ->
      queue = new BattleQueue()
      queue.add('batman', 'batman', {})
      queue.add('batman', 'batman', {})
      queue.should.have.length 1

    it 'cannot queue falsy references', ->
      queue = new BattleQueue()
      queue.add(null, null, {})
      queue.add(false, false, {})
      queue.add(undefined, undefined, {})
      queue.should.have.length 0

  describe '#remove', ->
    it 'can dequeue old players', ->
      queue = new BattleQueue()
      player = 'abc'
      queue.add(player, player, {})
      queue.remove(player)
      queue.size().should.equal 0

    it "can take an array of players", ->
      queue = new BattleQueue()
      player1 = 'abc'
      player2 = 'def'
      queue.add(player1, player1, {})
      queue.add(player2, player2, {})
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
      queue.add('batman', 'Bruce Wayne')
      queue.add('superman', 'Clark Kent')
      queue.add('flash', 'Wally West')
      queue.add('spiderman', 'Peter Parker')
      queue.pairPlayers (err, results) ->
        should.not.exist(err)
        should.exist(results)
        results.should.be.instanceOf(Array)
        results.should.have.length(2)
        done()

    it 'returns id/name/team/ratingkeyobjects', (done) ->
      queue = new BattleQueue()
      queue.add('batman', 'Bruce Wayne', [], 'bat')
      queue.add('superman', 'Clark Kent', [], 'supes')
      queue.pairPlayers (err, results) ->
        should.not.exist(err)
        should.exist(results)
        results.should.eql [[
          {id: 'batman', name: 'Bruce Wayne', team: [], ratingKey: 'bat' }
          {id: 'superman', name: 'Clark Kent', team: [], ratingKey: 'supes' }
        ]]
        done()

    it "returns an array of pairs in the order of their rating", (done) ->
      scores = [["batman", 1], ["superman", 4], ["flash", 3], ["spiderman", 2]]
      callbacks = for [player, score] in scores
        ratings.setRating.bind(ratings, player, score)
      async.parallel callbacks, ->
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
            [result[0].id, result[1].id]
          results.should.eql [[ "batman", "spiderman" ]
                              [ "flash", "superman"   ]]
          done()

    it "returns a different ordering for alts ratings", (done) ->
      users = [
        ["batman", "Bruce Wayne", 1, 1]
        ["superman", "Clark Kent", 4, 4]
        ["flash", "Wally West", 3, 2]
        ["spiderman", "Peter Parker", 2, 3]
      ]

      ratingTasks = []
      for user in users 
        # non-alt
        ratingTasks.push ratings.setRating.bind(null, user[0], user[2])
        
        # alt
        altId = alts.uniqueId(user[0], user[1])
        ratingTasks.push ratings.setRating.bind(this, altId, user[3])

      async.series ratingTasks, ->
        queue = new BattleQueue()        
        queue.add(user[0])  for user in users
        queue.pairPlayers (err, results) ->
          should.not.exist(err)
          results = results.map((result) -> [result[0].id, result[1].id])
          results.should.eql [[ "batman", "spiderman" ], [ "flash", "superman" ]]

          # now test alts getting added   
          queue.add(user[0], user[1], null, alts.uniqueId(user[0], user[1]))  for user in users
          queue.pairPlayers (err, results) ->
            should.not.exist(err)
            results = results.map((result) -> [result[0].id, result[1].id])
            results.should.eql [["batman", "flash"], ["spiderman", "superman"]]
            done()
