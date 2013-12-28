require('../helpers')

should = require('should')
commands = require('../../server/commands')
auth = require('../../server/auth')
{User} = require('../../server/user')
{Room} = require('../../server/rooms')
ratings = require('../../server/ratings')

describe "Commands", ->
  beforeEach ->
    @room = new Room()
    @user1 = new User("Star Fox")
    @user2 = new User("Slippy")
    @room.addUser(@user1)
    @room.addUser(@user2)
    @emptyRoom = new Room()

  describe "#executeCommand", ->
    describe "an invalid command", ->
      it "returns an error to the user", ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand(@user1, @room, "an invalid command")
        mock1.verify()
        mock2.verify()

    describe "rating", ->
      user1Rating = 9001
      user2Rating = 101

      beforeEach (done) ->
        ratings.setRating @user1.id, user1Rating, =>
          ratings.setRating(@user2.id, user2Rating, done)

      it "returns the user's rating to the user without arguments", (done) ->
        commands.executeCommand @user1, @room, "rating", (err, results) =>
          if err then throw err
          should.exist(results)
          results.should.have.property("username")
          results.should.have.property("rating")
          results.username.should.equal(@user1.id)
          results.rating.should.equal(user1Rating)
          done()

      it "returns someone's rating to the user as an argument", (done) ->
        commands.executeCommand @user1, @room, "rating", @user2.id, (err, results) =>
          if err then throw err
          should.exist(results)
          results.should.have.property("username")
          results.should.have.property("rating")
          results.username.should.equal(@user2.id)
          results.rating.should.equal(user2Rating)
          done()

    describe "kick", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @user1, @room, "kick", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "kicks someone if a moderator", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('close').never()
        mock2 = @sandbox.mock(@user2).expects('close').once()
        commands.executeCommand @user1, @room, "kick", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "adds a reason if applicable", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('close').never()
        mock2 = @sandbox.mock(@user2).expects('close').once()
        commands.executeCommand @user1, @room, "kick", @user2.id, "smelly", ->
          mock1.verify()
          mock2.verify()
          done()

      it "returns an error with an invalid argument", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @user1, @room, "kick", ->
          mock1.verify()
          mock2.verify()
          done()

      it "returns an error with a user who is not online", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @user1, @room, "kick", "offline user", ->
          mock1.verify()
          mock2.verify()
          done()

    describe "mod", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @user1, @room, "mod", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "mods a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @user1, @room, "mod", @user2.id, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.MOD)
          done()
