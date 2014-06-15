require('../helpers')

should = require('should')
async = require 'async'
commands = require('../../server/commands')
alts = require('../../server/alts')
auth = require('../../server/auth')
{User} = require('../../server/user')
{BattleServer} = require('../../server/server')
{Room} = require('../../server/rooms')
ratings = require('../../server/ratings')
{Factory} = require '../factory'
redis = require('../../server/redis')

generateTeam = ->
  [ Factory("Magikarp")
    Factory("Gyarados")
    Factory('Hitmonchan')
    Factory("Celebi")
    Factory("Blissey")
    Factory("Alakazam") ]

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
        spy = @sandbox.spy(@user1, 'announce')
        commands.executeCommand @server, @user1, @room, "rating", =>
          spy.callCount.should.equal(1)
          spy.firstCall.args[1].should.include(@user1.name)
          spy.firstCall.args[1].should.include(user1Rating)
          done()

      it "returns someone's rating to the user as an argument", (done) ->
        spy = @sandbox.spy(@user1, 'announce')
        commands.executeCommand @server, @user1, @room, "rating", @user2.id, =>
          spy.callCount.should.equal(1)
          spy.callCount.should.equal(1)
          spy.firstCall.args[1].should.include(@user2.name)
          spy.firstCall.args[1].should.include(user2Rating)
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

    describe "driver", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "driver", @user2.id, ->
          mock1.verify()
          mock2.verify()
          done()

      it "drivers a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "driver", @user2.id, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.DRIVER)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "driver", @offline.id, =>
          auth.getAuth @offline.id, (err, result) ->
            result.should.equal(auth.levels.DRIVER)
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
            ttl.should.equal(60 * 60)
            done()

      it "bans a user even if user isn't on yet", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @offline.id, =>
          mock1.verify()
          auth.getBanTTL @offline.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(60 * 60)
            done()

      it "bans a user for a specified amount of time", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, "23h", =>
          mock.verify()
          auth.getBanTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(23 * 60 * 60)
            done()

      it "defaults to an hour if banning for zero minutes", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, "0", =>
          mock.verify()
          auth.getBanTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(60 * 60)
            done()

      it "cannot ban over one day if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, "1y", =>
          mock.verify()
          auth.getBanTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(1 * 24 * 60 * 60)
            done()

      it "cannot ban over one week if admin", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.ADMIN
        commands.executeCommand @server, @user1, @room, "ban", @user2.id, "1y", =>
          mock.verify()
          auth.getBanTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(7 * 24 * 60 * 60)
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

      it "mutes a user for a specified amount of time", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, "23h", =>
          mock.verify()
          auth.getMuteTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(23 * 60 * 60)
            done()

      it "defaults to 10 if muting for zero minutes", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, "0", =>
          mock.verify()
          auth.getMuteTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

      it "cannot mute over two days if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, "1y", =>
          mock.verify()
          auth.getMuteTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(2 * 24 * 60 * 60)
            done()

      it "cannot mute over two weeks if admin", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.ADMIN
        commands.executeCommand @server, @user1, @room, "mute", @user2.id, "1y", =>
          mock.verify()
          auth.getMuteTTL @user2.id, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(2 * 7 * 24 * 60 * 60)
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
        @server.queuePlayer(@user1.id, generateTeam()).should.be.empty
        @server.queuePlayer(@user2.id, generateTeam()).should.be.empty
        @server.queuePlayer("aardvark", generateTeam()).should.be.empty
        @server.queuePlayer("bologna", generateTeam()).should.be.empty
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          battleIds.length.should.equal(2)
          spy = @sandbox.spy(@user1, 'announce')
          commands.executeCommand @server, @user1, @room, "battles", @user2.name, =>
            spy.callCount.should.equal(1)
            spy.firstCall.args[1].should.include(@user2.name)
            spy.firstCall.args[1].should.include(battleIds[0])
            spy.firstCall.args[1].should.not.include(@user1.name)
            spy.firstCall.args[1].should.not.include(battleIds[1])
            done()

      it "does not include alts in the battle list", (done) ->
        @server.queuePlayer(@user1.id, [ Factory("Magikarp") ])
        @server.queuePlayer(@user2.id, [ Factory("Magikarp") ], "Im an Alt")
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          spy = @sandbox.spy(@user1, 'announce')
          commands.executeCommand @server, @user1, @room, "battles", @user2.name, =>
            if err then throw err
            spy.callCount.should.equal(1)
            spy.firstCall.args[1].should.include(@user2.name)
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
        mock = @sandbox.mock(@room).expects('announce').once()
        spy1 = @sandbox.spy(@user1, 'send')
        spy2 = @sandbox.spy(@user2, 'send')
        @server.queuePlayer(@user1.id, generateTeam()).should.be.empty
        @server.queuePlayer(@user2.id, generateTeam()).should.be.empty
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          @user1.authority = auth.levels.ADMIN
          commands.executeCommand @server, @user1, @room, "wall", "derper", =>
            mock.verify()
            spy1.calledWithMatch("rawBattleMessage", battleIds[0], "derper").should.be.true
            spy2.calledWithMatch("rawBattleMessage", battleIds[0], "derper").should.be.true
            done()

    describe "lockdown", ->
      it "returns an error if insufficient authority", (done) ->
        mock = @sandbox.mock(@user1).expects('error').once()
        commands.executeCommand @server, @user1, @room, "lockdown", ->
          mock.verify()
          done()

      it "stops battles from occuring", (done) ->
        mock = @sandbox.mock(@server).expects('lockdown').once()
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "lockdown", ->
          mock.verify()
          done()

      it "can start them again", (done) ->
        mock = @sandbox.mock(@server).expects('unlockdown').once()
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "lockdown", "off", ->
          mock.verify()
          done()

    describe "whois", ->
      beforeEach (done) ->
        async.parallel([
          alts.createAlt.bind(alts, @user1.name, 'alt1')
          alts.createAlt.bind(alts, @user1.name, 'alt2')
        ], done)

      it "returns an error if insufficient authority", (done) ->
        mock = @sandbox.mock(@user1).expects('error').once()
        commands.executeCommand @server, @user1, @room, "whois", @user1.name, =>
          mock.verify()
          done()

      it "returns a list of alts and the main account", (done) ->
        @user1.authority = auth.levels.MOD
        spy = @sandbox.spy(@user1, 'announce')
        commands.executeCommand @server, @user1, @room, "whois", @user1.name, =>
          spy.callCount.should.equal(1)
          spy.firstCall.args[1].should.include(@user1.name)
          spy.firstCall.args[1].should.include("alt1")
          spy.firstCall.args[1].should.include("alt2")
          done()
