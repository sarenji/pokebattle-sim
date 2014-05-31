require('./helpers')

should = require('should')
ratings = require('../server/ratings')
async = require('async')
alts = require('../server/alts')

describe "Ratings", ->
  describe "#getPlayer", ->
    it "returns default information for new players", (done) ->
      ratings.getPlayer "bogus player", (err, result) ->
        should.not.exist(err)
        should.exist(result)
        result.should.be.instanceOf(Object)
        result.should.containEql(rating: 0)
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
            results[0].should.equal(0)
            results[1].should.not.equal(0)
            defaultRating = ratings.algorithm.createPlayer().rating
            results[1].should.be.lessThan(defaultRating)
            done()

  describe "#getMaxRating", ->
    it "returns the rating of a user if there's no alts", (done) ->
      ratings.setRating "user", 25, (err) ->
        ratings.getMaxRating "user", (err, result) ->
          result.should.equal(25)
          done()

    it "returns the maximum rating of a user and their alts", (done) ->
      altOps = ["alt1","alt2"].map (altName) -> 
        (callback) -> alts.createAlt("user", altName, callback)
      
      async.parallel altOps, ->
        ratings.setRating "user", 25, (err) ->
          ratings.setRating alts.uniqueId("user", "alt1"), 5, (err) ->
            ratings.setRating alts.uniqueId("user", "alt2"), 30, (err) ->
              ratings.getMaxRating "user", (err, result) ->
                result.should.equal(30)
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

    it "returns up to the maximum per page", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.updatePlayers "player3", "player4", ratings.results.WIN, ->
          ratings.listRatings 1, 2, (err, results) ->
            should.not.exist(err)
            results.should.have.length(2)
            done()

    it "does not include alts", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        altName = alts.uniqueId('player1', 'altName')
        ratings.updatePlayers altName, "player2", ratings.results.WIN, ->
          ratings.listRatings 0, 100, (err, results) ->
            results.length.should.equal(2)
            results.some((r) -> r.username == altName).should.be.false
            done()

    it "returns the max rating for a user and their alts", (done) ->
      # Operations to create alts and then set the rating
      altOps = [["alt1", 5], ["alt2", 30]].map (pair) -> 
        (callback) -> 
          [altName, rating] = pair
          alts.createAlt "user", altName, ->
            ratings.setRating(alts.uniqueId("user", altName), rating, callback)

      async.parallel altOps, ->
        ratings.setRating "user", 15, ->
          ratings.listRatings 0, 100, (err, results) ->
            results.should.eql([{username: "user", score: 30}])
            done()

  describe '#getRatio', ->
    it "returns a hash containing the win, lose, and draw counts", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
          ratings.updatePlayers "player2", "player1", ratings.results.WIN, ->
            ratings.getRatio "player1", (err, player1Ratio) ->
              player1Ratio.should.eql(win: 2, lose: 1, draw: 0)
              ratings.getRatio "player2", (err, player2Ratio) ->
                player2Ratio.should.eql(win: 1, lose: 2, draw: 0)
                done()

  describe '#getRank', ->
    it "returns the rank of a player", (done) ->
      ratings.updatePlayers "player1", "player2", ratings.results.WIN, ->
        ratings.getRank "player1", (err, rank) ->
          rank.should.equal(1)
          ratings.getRank "player2", (err, rank) ->
            rank.should.equal(2)
            ratings.updatePlayers "player2", "player1", ratings.results.WIN, ->
              ratings.updatePlayers "player2", "player1", ratings.results.WIN, ->
                ratings.getRank "player1", (err, rank) ->
                  rank.should.equal(2)
                  ratings.getRank "player2", (err, rank) ->
                    rank.should.equal(1)
                    done()
