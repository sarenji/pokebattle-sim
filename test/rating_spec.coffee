require('./helpers')

should = require('should')
ratings = require('../server/ratings')

describe "Ratings", ->
  describe "#getPlayer", ->
    it "returns default information for new players", (done) ->
      ratings.getPlayer "bogus player", (err, result) ->
        should.not.exist(err)
        should.exist(result)
        result.should.be.instanceOf(Object)
        result.should.eql(ratings.algorithm.createPlayer())
        done()

    it "returns information for an existing player", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.getPlayer "player1", (err, result) ->
          should.not.exist(err)
          should.exist(result)
          result.should.be.instanceOf(Object)
          result.rating.should.be.greaterThan(ratings.algorithm.createPlayer().rating)
          done()
