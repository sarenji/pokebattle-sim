require '../helpers'

{Room} = require '../../server/rooms'
{User} = require '../../server/user'

describe "A server room:", ->
  describe "#addUser", ->
    it "returns the number of connections with that id", ->
      room = new Room()
      room.addUser(new User("derp")).should.equal(1)
      room.addUser(new User("derp")).should.equal(2)
      room.addUser(new User("herp")).should.equal(1)

  describe "#removeUser", ->
    it "returns the number of remaining connections with that id", ->
      room = new Room()
      room.addUser(new User("derp"))
      room.addUser(new User("derp"))
      room.removeUser(new User("derp")).should.equal(1)
      room.removeUser(new User("derp")).should.equal(0)
      room.removeUser(new User("derp")).should.equal(0)

  describe "#message", ->
    it "sends a message to all users in that room", ->
      room = new Room()
      room.addUser(user1 = new User("aaaa"))
      room.addUser(user2 = new User("bbbb"))
      mock1 = @sandbox.mock(user1)
      mock1.expects('send').withArgs("raw message", "hello").once()
      mock2 = @sandbox.mock(user2)
      mock2.expects('send').withArgs("raw message", "hello").once()

      room.message("hello")
      mock1.verify()
      mock2.verify()

  describe "#userMessage", ->
    it "sends a message to all users in that room", ->
      room = new Room()
      room.addUser(user1 = new User("aaaa"))
      room.addUser(user2 = new User("bbbb"))
      mock1 = @sandbox.mock(user1).expects('send')
      mock1.withArgs("update chat", user1.id, "hello").once()
      mock2 = @sandbox.mock(user2).expects('send').once()
      mock2.withArgs("update chat", user1.id, "hello").once()

      room.userMessage(user1, "hello")
      mock1.verify()
      mock2.verify()

  describe "#userJSON", ->
    it "returns an array containing the JSON of all users", ->
      room = new Room()
      room.addUser(user1 = new User("aaaa"))
      room.addUser(user2 = new User("bbbb"))
      room.userJSON().should.eql([ {id: user1.id}, {id: user2.id} ])

  describe "#send", ->
    it "broadcasts to every single user, including ones on the same account", ->
      room = new Room()
      room.addUser(user1 = new User("aaaa"))
      room.addUser(user2 = new User("aaaa"))
      mock1 = @sandbox.mock(user1).expects('send').withArgs('hello').once()
      mock2 = @sandbox.mock(user2).expects('send').withArgs('hello').once()
      room.send("hello")
      mock1.verify()
      mock2.verify()

    it "stops broadcasting to users that leave", ->
      room = new Room()
      room.addUser(user1 = new User("aaaa"))
      room.addUser(user2 = new User("aaaa"))
      mock1 = @sandbox.mock(user1).expects('send').withArgs('hello').never()
      mock2 = @sandbox.mock(user2).expects('send').withArgs('hello').once()

      room.removeUser(user1)
      room.send("hello")

      mock1.verify()
      mock2.verify()

      room.removeUser(user1)
      mock1.verify()
      mock2.verify()
