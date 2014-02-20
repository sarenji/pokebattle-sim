require('../helpers')

should = require('should')
commands = require('../../server/commands')
auth = require('../../server/auth')
{User} = require('../../server/user')
{BattleServer} = require('../../server/server')
{Room} = require('../../server/rooms')
ratings = require('../../server/ratings')
{Factory} = require '../factory'
db = require('../../server/database')

describe "Commands", ->
  beforeEach ->
    @room = new Room()
    @user1 = new User("Star Fox")
    @user2 = new User("Slippy")
    @offline = new User("husk")
    @room.addUser(@user1)
    @room.addUser(@user2)
    @emptyRoom = new Room()
    @server = new BattleServer()
    @server.rooms.push(@room)
    @server.join(@user1)
    @server.join(@user2)

  afterEach (done) ->
    db.flushdb(done)

  describe "#executeCommand", ->
    describe "an invalid command", ->
      it "returns an error to the user", ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand(@server, @user1, @room, "an invalid command")
        mock1.verify()
        mock2.verify()

    describe "rating", ->
      user1Rating = 9001
      user2Rating = 101

      beforeEach (done) ->
        ratings.setRating @user1.id, user1Rating, =>
          ratings.setRating(@user2.id, user2Rating, done)

      it "returns the user's rating to the user without arguments", (done) ->
        commands.executeCommand @server, @user1, @room, "rating", (err, results) =>
          if err then throw err
          should.exist(results)
          results.should.have.property("username")
          results.should.have.property("rating")
          results.username.should.equal(@user1.id)
          results.rating.should.equal(user1Rating)
          done()

      it "returns someone's rating to the user as an argument", (done) ->
        commands.executeCommand @server, @user1, @room, "rating", @user2.id, (err, results) =>
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
        commands.executeCommand @server, @user1, @room, "kick", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "kicks someone if a moderator", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('close').never()
        mock2 = @sandbox.mock(@user2).expects('close').once()
        commands.executeCommand @server, @user1, @room, "kick", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "adds a reason if applicable", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('close').never()
        mock2 = @sandbox.mock(@user2).expects('close').once()
        commands.executeCommand @server, @user1, @room, "kick", @user2.id, "smelly", ->
          mock1.verify()
          mock2.verify()
          done()

      it "returns an error with an invalid argument", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "kick", ->
          mock1.verify()
          mock2.verify()
          done()

      it "returns an error with a user who is not online", (done) ->
        @user1.authority = auth.levels.MOD
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "kick", @offline.id, ->
          mock1.verify()
          mock2.verify()
          done()

    describe "mod", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "mod", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "mods a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "mod", @user2.id, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.MOD)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "mod", @offline.id, =>
          auth.getAuth @offline.id, (err, result) ->
            result.should.equal(auth.levels.MOD)
            done()

    describe "admin", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "admin", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "admins a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "admin", @user2.id, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.ADMIN)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "admin", @offline.id, =>
          auth.getAuth @offline.id, (err, result) ->
            result.should.equal(auth.levels.ADMIN)
            done()

    describe "deauth", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "deauth", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "deauthes a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "deauth", @user2.id, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.USER)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "deauth", @offline.id, =>
          auth.getAuth @offline.id, (err, result) ->
            result.should.equal(auth.levels.USER)
            done()

    describe "ban", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "bans a user if mod", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        mock2 = @sandbox.mock(@user2).expects('close').once()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, =>
          mock1.verify()
          mock2.verify()
          auth.getBanTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(-1)
            done()

      it "bans a user even if user isn't on yet", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @offline.id, =>
          mock1.verify()
          auth.getBanTTL @offline.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(-1)
            done()

    describe "unban", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "unban", @user2.id, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unbans a user if mod", (done) ->
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, =>
            commands.executeCommand @server, @user1, @room, "unban", @user2.id, =>
              auth.getBanTTL @user2.id, (err, ttl) ->
                should.exist(ttl)
                ttl.should.equal(-2)
                done()

      it "returns an error if user is not banned", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "unban", @user2.id, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unbans a user even if user isn't on yet", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @offline.id, =>
          commands.executeCommand @server, @user1, @room, "unban", @offline.id, =>
            mock.verify()
            auth.getBanTTL @user2.id, (err, ttl) ->
              should.exist(ttl)
              ttl.should.equal(-2)
              done()

    describe "mute", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "mutes a user if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, =>
          mock.verify()
          auth.getMuteTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

      it "mutes a user even if user isn't on yet", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @offline.id, =>
          mock.verify()
          auth.getMuteTTL @offline.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

    describe "unmute", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "unmute", @user2.id, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unmutes a user if mod", (done) ->
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, =>
            commands.executeCommand @server, @user1, @room, "unmute", @user2.id, =>
              auth.getMuteTTL @user2.id, (err, ttl) ->
                should.exist(ttl)
                ttl.should.equal(-2)
                done()

      it "returns an error if user is not muted", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "unmute", @user2.id, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unmutes a user even if user isn't on yet", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @offline.id, =>
          commands.executeCommand @server, @user1, @room, "unmute", @offline.id, =>
            mock1.verify()
            auth.getMuteTTL @user2.id, (err, ttl) ->
              should.exist(ttl)
              ttl.should.equal(-2)
              done()

    describe "battles", ->
      it "returns an error if no user is passed", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "battles", ->
          mock1.verify()
          mock2.verify()
          done()

      it "returns all battles that user is in if user is passed", (done) ->
        @server.queuePlayer(@user1.id, [ Factory("Magikarp") ])
        @server.queuePlayer(@user2.id, [ Factory("Magikarp") ])
        @server.queuePlayer("aardvark", [ Factory("Magikarp") ])
        @server.queuePlayer("bologna", [ Factory("Magikarp") ])
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          commands.executeCommand @server, @user1, @room, "battles", @user2.id, (err, battleIds) =>
            if err then throw err
            battleIds.should.eql(@server.getUserBattles(@user2.id))
            done()

    describe "topic", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        commands.executeCommand @server, @user1, @room, "topic", "test topic", ->
          mock1.verify()
          done()

      it "updates the channel topic", (done) ->
        topicName = "a test"
        @user1.authority = auth.levels.ADMIN
        mock = @sandbox.mock(@room).expects("setTopic").withArgs(topicName).once()
        commands.executeCommand @server, @user1, @room, "topic", topicName, ->
          mock.verify()
          done()

    describe "wall", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        commands.executeCommand @server, @user1, @room, "wall", "hi", ->
          mock1.verify()
          done()

      it "messages all rooms and all battles", (done) ->
        mock = @sandbox.mock(@room).expects('message').once()
        spy1 = @sandbox.spy(@user1, 'send')
        spy2 = @sandbox.spy(@user2, 'send')
        @server.queuePlayer(@user1.id, [ Factory("Magikarp") ])
        @server.queuePlayer(@user2.id, [ Factory("Magikarp") ])
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          @user1.authority = auth.levels.ADMIN
          commands.executeCommand @server, @user1, @room, "wall", "derper", =>
            mock.verify()
            spy1.calledWithMatch("raw battle message", battleIds[0], "derper").should.be.true
            spy2.calledWithMatch("raw battle message", battleIds[0], "derper").should.be.true
            done()

    describe "help", ->
      it "messages all available commands to that user", (done) ->
        mock1 = @sandbox.mock(@user1).expects('message').once()
        mock2 = @sandbox.mock(@user2).expects('message').never()
        commandNames = (name  for name of commands.HelpDescriptions)
        commands.executeCommand @server, @user1, @room, "help", (err, msg) ->
          should.not.exist(err)
          should.exist(msg)
          for commandName in commandNames
            msg.should.include(commandName)
          mock1.verify()
          mock2.verify()
          done()
