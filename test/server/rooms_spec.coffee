{Room} = require '../../server/rooms'

describe "A server room:", ->
  describe "#addUser", ->
    it "returns the number of connections with that id", ->
      room = new Room()
      room.addUser("derp").should.equal(1)
      room.addUser("derp").should.equal(2)
      room.addUser("herp").should.equal(1)

  describe "#removeUser", ->
    it "returns the number of remaining connections with that id", ->
      room = new Room()
      socket1 = "derp"
      socket2 = "derp"
      room.addUser(socket1)
      room.addUser(socket2)
      room.removeUser(socket1).should.equal(1)
      room.removeUser(socket2).should.equal(0)
      room.removeUser(socket2).should.equal(0)
