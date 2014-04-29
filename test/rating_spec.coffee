require('./helpers')

should = require('should')
ratings = require('../server/ratings')
db = require('../server/database')

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

  describe "#resetRating", ->
    it "resets the rating of a player", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.resetRating "player1", ->
          ratings.getRatings [ "player1", "player2" ], (err, results) ->
            results[0].should.eql ratings.algorithm.createPlayer().rating
            results[1].should.be.lessThan(results[0])
            done()

  describe "#listRatings", ->
    it "returns a list of ratings", (done) ->
      r = []
      # 1 > 3 > 2
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.updatePlayers "player3", "player2", ratings.results.WIN, ->
          ratings.getRatings [1..3].map((i) -> "player#{i}"), (err, scores) ->
            ratings.listRatings 1, 2, (err, results) ->
              r = r.concat(results)
              ratings.listRatings 2, 2, (err, results) ->
                r = r.concat(results)
                r.should.eql([
                  {username: "player1", score: scores[0]}
                  {username: "player3", score: scores[2]}
                  {username: "player2", score: scores[1]}
                ])
                done()
