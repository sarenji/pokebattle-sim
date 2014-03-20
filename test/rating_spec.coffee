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
      # 1 > 3 > 5 > 2 > 4 > 6
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.updatePlayers "player3", "player4", ratings.results.WIN, ->
          ratings.updatePlayers "player5", "player6", ratings.results.WIN, ->
            ratings.updatePlayers "player1", "player3", ratings.results.WIN, ->
              ratings.updatePlayers "player3", "player5", ratings.results.WIN, ->
                ratings.updatePlayers "player1", "player5", ratings.results.WIN, ->
                  ratings.updatePlayers "player2", "player4", ratings.results.WIN, ->
                    ratings.updatePlayers "player4", "player6", ratings.results.WIN, ->
                      ratings.updatePlayers "player5", "player2", ratings.results.WIN, ->
                        ratings.getRatings [1..6].map((i) -> "player#{i}"), (err, scores) ->
                          ratings.listRatings 1, 2, (err, results) ->
                            results.should.eql([["player1", scores[0]], ["player3", scores[2]]])
                            ratings.listRatings 2, 2, (err, results) ->
                              results.should.eql([["player5", scores[4]], ["player2", scores[1]]])
                              ratings.listRatings 3, 2, (err, results) ->
                                results.should.eql([["player4", scores[3]], ["player6", scores[5]]])
                                done()
