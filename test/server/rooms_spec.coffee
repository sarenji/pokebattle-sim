{Room} = require '../../server/rooms'

describe "A server room:", ->
  describe "#addUser", ->
    it "returns the number of connections with that id", ->
      room = new Room()
      room.addUser(id: "derp").should.equal(1)
      room.addUser(id: "derp").should.equal(2)
      room.addUser(id: "herp").should.equal(1)

  describe "#removeUser", ->
    it "returns the number of remaining connections with that id", ->
      room = new Room()
      socket1 = {id: "derp"}
      socket2 = {id: "derp"}
      room.addUser(socket1)
      room.addUser(socket2)
      room.removeUser(socket1).should.equal(1)
      room.removeUser(socket2).should.equal(0)
      room.removeUser(socket2).should.equal(0)
