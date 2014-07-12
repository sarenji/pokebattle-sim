require('../helpers')

should = require('should')
async = require 'async'
primus = require('primus')
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
    @server = new BattleServer()
    @room = new Room()
    @spark1 = @stubSpark()
    @spark2 = @stubSpark()
    @user1 = @server.findOrCreateUser(id: 1, name: "Star Fox", @spark1)
    @user2 = @server.findOrCreateUser(id: 2, name: "Slippy", @spark2)
    @aardvark = @server.findOrCreateUser(id: 3, name: 'aardvark', @stubSpark())
    @bologna = @server.findOrCreateUser(id: 3, name: 'bologna', @stubSpark())
    @offlineName = "husk"
    @room.add(@spark1)
    @room.add(@spark2)
    @emptyRoom = new Room()
    @server.rooms.push(@room)
    @server.join(@spark1)
    @server.join(@spark2)

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
        ratings.setRating @user1.name, user1Rating, =>
          ratings.setRating(@user2.name, user2Rating, done)

      it "returns the user's rating to the user without arguments", (done) ->
        spy = @sandbox.spy(@user1, 'announce')
        commands.executeCommand @server, @user1, @room, "rating", =>
          spy.callCount.should.equal(1)
          spy.firstCall.args[1].should.containEql(@user1.name)
          spy.firstCall.args[1].should.containEql(user1Rating)
          done()

      it "returns someone's rating to the user as an argument", (done) ->
        spy = @sandbox.spy(@user1, 'announce')
        commands.executeCommand @server, @user1, @room, "rating", @user2.name, =>
          spy.callCount.should.equal(1)
          spy.callCount.should.equal(1)
          spy.firstCall.args[1].should.containEql(@user2.name)
          spy.firstCall.args[1].should.containEql(user2Rating)
          done()

    describe "voice", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "voice", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "voices a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "voice", @user2.name, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.DRIVER)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "voice", @offlineName, =>
          auth.getAuth @offlineName, (err, result) ->
            result.should.equal(auth.levels.DRIVER)
            done()

    describe "mod", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "mod", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "mods a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "mod", @user2.name, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.MOD)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "mod", @offlineName, =>
          auth.getAuth @offlineName, (err, result) ->
            result.should.equal(auth.levels.MOD)
            done()

    describe "admin", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "admin", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "admins a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "admin", @user2.name, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.ADMIN)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "admin", @offlineName, =>
          auth.getAuth @offlineName, (err, result) ->
            result.should.equal(auth.levels.ADMIN)
            done()

    describe "deauth", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "deauth", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "deauthes a user if owner", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "deauth", @user2.name, =>
          @user2.should.have.property("authority")
          @user2.authority.should.equal(auth.levels.USER)
          done()

      it "does not crash if user isn't on yet", (done) ->
        @user1.authority = auth.levels.OWNER
        commands.executeCommand @server, @user1, @room, "deauth", @offlineName, =>
          auth.getAuth @offlineName, (err, result) ->
            result.should.equal(auth.levels.USER)
            done()

    describe "ban", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@spark2).expects('end').never()
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "bans a user if mod", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        mock2 = @sandbox.mock(@spark2).expects('end').once()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, =>
          mock1.verify()
          mock2.verify()
          auth.getBanTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(60 * 60)
            done()

      it "bans a user even if user isn't on yet", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @offlineName, =>
          mock1.verify()
          auth.getBanTTL @offlineName, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(60 * 60)
            done()

      it "bans a user for a specified amount of time", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, "23h", =>
          mock.verify()
          auth.getBanTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(23 * 60 * 60)
            done()

      it "defaults to an hour if banning for zero minutes", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, "0", =>
          mock.verify()
          auth.getBanTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(60 * 60)
            done()

      it "cannot ban over one day if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, "1y", =>
          mock.verify()
          auth.getBanTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(1 * 24 * 60 * 60)
            done()

      it "cannot ban over one week if admin", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.ADMIN
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, "1y", =>
          mock.verify()
          auth.getBanTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(7 * 24 * 60 * 60)
            done()

    describe "unban", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "unban", @user2.name, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unbans a user if mod", (done) ->
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @user2.name, =>
            commands.executeCommand @server, @user1, @room, "unban", @user2.name, =>
              auth.getBanTTL @user2.name, (err, ttl) ->
                should.exist(ttl)
                ttl.should.equal(-2)
                done()

      it "returns an error if user is not banned", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "unban", @user2.name, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unbans a user even if user isn't on yet", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "ban", @offlineName, =>
          commands.executeCommand @server, @user1, @room, "unban", @offlineName, =>
            mock.verify()
            auth.getBanTTL @user2.name, (err, ttl) ->
              should.exist(ttl)
              ttl.should.equal(-2)
              done()

    describe "mute", ->
      it "returns an error if insufficient authority", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, ->
          mock1.verify()
          mock2.verify()
          done()

      it "mutes a user if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, =>
          mock.verify()
          auth.getMuteTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

      it "mutes a user even if user isn't on yet", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @offlineName, =>
          mock.verify()
          auth.getMuteTTL @offlineName, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

      it "mutes a user for a specified amount of time", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, "23h", =>
          mock.verify()
          auth.getMuteTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(23 * 60 * 60)
            done()

      it "defaults to 10 if muting for zero minutes", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, "0", =>
          mock.verify()
          auth.getMuteTTL @user2.name, (err, ttl) ->
            should.exist(ttl)
            ttl.should.equal(10 * 60)
            done()

      it "cannot mute over two days if mod", (done) ->
        mock = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, "1y", =>
          mock.verify()
          auth.getMuteTTL @user2.name, (err, ttl) ->
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
        commands.executeCommand @server, @user1, @room, "unmute", @user2.name, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unmutes a user if mod", (done) ->
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @user2.name, =>
            commands.executeCommand @server, @user1, @room, "unmute", @user2.name, =>
              auth.getMuteTTL @user2.name, (err, ttl) ->
                should.exist(ttl)
                ttl.should.equal(-2)
                done()

      it "returns an error if user is not muted", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').once()
        mock2 = @sandbox.mock(@user2).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "unmute", @user2.name, =>
          mock1.verify()
          mock2.verify()
          done()

      it "unmutes a user even if user isn't on yet", (done) ->
        mock1 = @sandbox.mock(@user1).expects('error').never()
        @user1.authority = auth.levels.MOD
        commands.executeCommand @server, @user1, @room, "mute", @offlineName, =>
          commands.executeCommand @server, @user1, @room, "unmute", @offlineName, =>
            mock1.verify()
            auth.getMuteTTL @user2.name, (err, ttl) ->
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
        @server.queuePlayer(@user1.name, generateTeam()).should.be.empty
        @server.queuePlayer(@user2.name, generateTeam()).should.be.empty
        @server.queuePlayer(@aardvark.name, generateTeam()).should.be.empty
        @server.queuePlayer(@bologna.name, generateTeam()).should.be.empty
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          battleIds.length.should.equal(2)
          spy = @sandbox.spy(@user1, 'announce')
          commands.executeCommand @server, @user1, @room, "battles", @user2.name, =>
            spy.callCount.should.equal(1)
            spy.firstCall.args[1].should.containEql(@user2.name)
            spy.firstCall.args[1].should.containEql(battleIds[0])
            spy.firstCall.args[1].should.not.containEql(@user1.name)
            spy.firstCall.args[1].should.not.containEql(battleIds[1])
            done()

      it "does not containEql alts in the battle list", (done) ->
        @server.queuePlayer(@user1.name, [ Factory("Magikarp") ])
        @server.queuePlayer(@user2.name, [ Factory("Magikarp") ], "Im an Alt")
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          spy = @sandbox.spy(@user1, 'announce')
          commands.executeCommand @server, @user1, @room, "battles", @user2.name, =>
            if err then throw err
            spy.callCount.should.equal(1)
            spy.firstCall.args[1].should.containEql(@user2.name)
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
        spy1 = @sandbox.spy(@spark1, 'send')
        spy2 = @sandbox.spy(@spark2, 'send')
        @server.queuePlayer(@user1.name, generateTeam()).should.be.empty
        @server.queuePlayer(@user2.name, generateTeam()).should.be.empty
        @server.beginBattles (err, battleIds) =>
          if err then throw err
          @user1.authority = auth.levels.ADMIN
          commands.executeCommand @server, @user1, @room, "wall", "derper", =>
            mock.verify()
            console.log()
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
          spy.firstCall.args[1].should.containEql(@user1.name)
          spy.firstCall.args[1].should.containEql("alt1")
          spy.firstCall.args[1].should.containEql("alt2")
          done()
