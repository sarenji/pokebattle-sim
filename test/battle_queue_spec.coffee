require './helpers'

should = require 'should'
async = require 'async'
{BattleQueue} = require('../server/queue')
redis = require('../server/redis')
ratings = require('../server/ratings')
alts = require('../server/alts')
async = require('async')

FORMAT = 'xy1000'

describe 'BattleQueue', ->
  it 'should be empty by default', ->
    new BattleQueue(FORMAT).should.have.length(0)

  describe '#add', ->
    it 'queues a new player', ->
      queue = new BattleQueue(FORMAT)
      queue.add('derp', 'derp', {})
      queue.should.have.length 1

    it 'queues two players', ->
      queue = new BattleQueue(FORMAT)
      queue.add('batman', 'batman', {})
      queue.add('superman', 'superman', {})
      queue.should.have.length 2

    it 'cannot queue the same player twice', ->
      queue = new BattleQueue(FORMAT)
      queue.add('batman', 'batman', {})
      queue.add('batman', 'batman', {})
      queue.should.have.length 1

    it 'cannot queue falsy references', ->
      queue = new BattleQueue(FORMAT)
      queue.add(null, null, {})
      queue.add(false, false, {})
      queue.add(undefined, undefined, {})
      queue.should.have.length 0

  describe '#remove', ->
    it 'can dequeue old players', ->
      queue = new BattleQueue(FORMAT)
      player = 'abc'
      queue.add(player, player, {})
      queue.remove(player)
      queue.size().should.equal 0

    it "can take an array of players", ->
      queue = new BattleQueue(FORMAT)
      player1 = 'abc'
      player2 = 'def'
      queue.add(player1, player1, {})
      queue.add(player2, player2, {})
      queue.remove([ player1, player2 ])
      queue.should.have.length 0

  describe '#queuedPlayers', ->
    it 'returns the players who are queued', ->
      queue = new BattleQueue(FORMAT)
      dude = 'dude'
      queue.add(dude)
      queue.queuedPlayers().should.containEql(dude)
      queue.queuedPlayers().should.have.length 1

  describe '#hasRecentlyMatched', ->
    it "returns false if two players have not queued", ->
      queue = new BattleQueue(FORMAT)
      queue.hasRecentlyMatched("p1", "p2").should.be.false

    it "returns true if two players have queued", ->
      queue = new BattleQueue(FORMAT)
      queue.addRecentMatch("p1", "p2")
      queue.hasRecentlyMatched("p1", "p2").should.be.true

    it "is not affected by ordering", ->
      queue = new BattleQueue(FORMAT)
      queue.addRecentMatch("p1", "p2")
      queue.hasRecentlyMatched("p1", "p2").should.be.true
      queue.hasRecentlyMatched("p2", "p1").should.be.true

    it "returns false if 30 minutes has passed since two players have queued", ->
      queue = new BattleQueue(FORMAT)
      queue.addRecentMatch("p1", "p2")
      queue.hasRecentlyMatched("p1", "p2").should.be.true
      @clock.tick(31 * 60 * 1000)
      queue.hasRecentlyMatched("p1", "p2").should.be.false

  describe '#pairPlayers', ->
    it 'takes players out of the queue', (done) ->
      queue = new BattleQueue(FORMAT)
      queue.add('batman')
      queue.add('superman')
      queue.pairPlayers ->
        queue.queuedPlayers().should.be.empty
        done()

    it 'leaves one person out if the queue length is odd', (done) ->
      queue = new BattleQueue(FORMAT)
      queue.add('batman')
      queue.add('superman')
      queue.add('flash')
      queue.pairPlayers ->
        queue.queuedPlayers().should.have.length 1
        done()

    it 'returns an array of pairs', (done) ->
      queue = new BattleQueue(FORMAT)
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
      queue = new BattleQueue(FORMAT)
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
        ratings.setRating.bind(ratings, FORMAT, player, score)
      async.parallel callbacks, ->
        queue = new BattleQueue(FORMAT)
        queue.add(pair[0])  for pair in scores
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

    it "does not match the same players twice", (done) ->
      scores = [["batman", 1], ["superman", 4], ["flash", 3], ["spiderman", 2]]
      callbacks = for [player, score] in scores
        ratings.setRating.bind(ratings, FORMAT, player, score)
      async.parallel callbacks, ->
        queue = new BattleQueue(FORMAT)
        queue.add(pair[0])  for pair in scores
        queue.pairPlayers (err, results) ->
          should.not.exist(err)
          results = results.map (result) ->
            [result[0].id, result[1].id]
          results.should.eql [[ "batman", "spiderman" ]
                              [ "flash", "superman"   ]]

          # now perform round two: Should get different results
          queue.add(pair[0])  for pair in scores
          queue.pairPlayers (err, results) ->
            should.not.exist(err)
            results = results.map (result) ->
              [result[0].id, result[1].id]
            results.should.eql [[ "batman", "flash" ]
                              [ "spiderman", "superman" ]]
            done()

    it "does not match players with a large rating gap until it expands", (done) ->
      scores = [["batman", 900], ["superman", 1005]]
      callbacks = for [player, score] in scores
        ratings.setRating.bind(ratings, FORMAT, player, score)
      async.parallel callbacks, ->
        queue = new BattleQueue(FORMAT)
        queue.add(pair[0])  for pair in scores

        # first run - no matches should be found
        queue.pairPlayers (err, results) ->
          should.not.exist(err)
          results.should.have.length 0

          # second run - should have found a match
          queue.pairPlayers (err, results) ->
            should.not.exist(err)
            results.should.have.length 1
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
        ratingTasks.push ratings.setRating.bind(null, FORMAT, user[0], user[2])

        # alt
        altId = alts.uniqueId(user[0], user[1])
        ratingTasks.push ratings.setRating.bind(this, FORMAT, altId, user[3])

      async.series ratingTasks, ->
        queue = new BattleQueue(FORMAT)
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
