require '../helpers'

{BattleServer} = require('../../server/server')
{Room} = require '../../server/rooms'
{User} = require '../../server/user'

describe "A server room:", ->
  beforeEach ->
    @server = new BattleServer()
    @spark1 = @stubSpark()
    @spark2 = @stubSpark()
    @user1 = @server.findOrCreateUser(id: 1, name: 'aaaa', @spark1)
    @user2 = @server.findOrCreateUser(id: 2, name: 'bbbb', @spark2)
    @room = new Room()
    @room.add(@spark1)
    @room.add(@spark2)

  describe "#message", ->
    it "sends a message to all users in that room", ->
      mock1 = @sandbox.mock(@user1)
      mock1.expects('send').withArgs("rawMessage", "hello").once()
      mock2 = @sandbox.mock(@user2)
      mock2.expects('send').withArgs("rawMessage", "hello").once()

      @room.message("hello")
      mock1.verify()
      mock2.verify()

  describe "#rawMessage", ->
    it "sends a message to all users in that room", ->
      mock1 = @sandbox.mock(@user1).expects('send')
      mock1.withArgs("rawMessage", @user1.name, "hello").once()
      mock2 = @sandbox.mock(@user2).expects('send').once()
      mock2.withArgs("rawMessage", @user1.name, "hello").once()

      @room.rawMessage(@user1, "hello")
      mock1.verify()
      mock2.verify()

  describe "#setTopic", ->
    it "sends a topic message to all users in that room", ->
      mock1 = @sandbox.mock(@user1).expects('send')
      mock1.withArgs("topic", "a test").once()
      mock2 = @sandbox.mock(@user2).expects('send').once()
      mock2.withArgs("topic", "a test").once()

      @room.setTopic("a test")
      mock1.verify()
      mock2.verify()

  describe "#userJSON", ->
    it "returns an array containing the JSON of all users", ->
      @room.toJSON().should.eql([ @user1.toJSON(), @user2.toJSON() ])

  describe "#send", ->
    it "broadcasts to every single user, including ones on the same account", ->
      mock1 = @sandbox.mock(@user1).expects('send').withArgs('hello').once()
      mock2 = @sandbox.mock(@user2).expects('send').withArgs('hello').once()
      @room.send("hello")
      mock1.verify()
      mock2.verify()

    it "stops broadcasting to sparks that leave", ->
      spy1 = @sandbox.spy(@user1, 'send')
      spy2 = @sandbox.spy(@user2, 'send')

      @room.remove(@spark1)
      @room.send("hello")

      spy1.withArgs('hello').called.should.be.false
      spy2.withArgs('hello').calledOnce.should.be.true

      @room.remove(@spark2)
      @room.send("hello")
      spy1.withArgs('hello').called.should.be.false
      spy2.withArgs('hello').calledOnce.should.be.true
