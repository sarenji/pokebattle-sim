{SocketHash} = require('./socket_hash')
db = require('./database')
errors = require('../shared/errors')

class @Room
  constructor: (@name) ->
    @users = new SocketHash()

  # Adds a user to this room.
  # Returns the number of connections that this user has.
  addUser: (user) ->
    @users.add(user)

  # Removes a user from this room.
  # Returns the number of remaining connections this user has.
  removeUser: (user) ->
    @users.remove(user)

  userMessage: (user, message) ->
    @send('updateChat', user.name, message)

  message: (message) ->
    @send('rawMessage', message)

  send: ->
    @users.broadcast.apply(@users, arguments)

  # Set the room's topic. Does not work for battle rooms.
  # TODO: Or rather, it shouldn't work for battle rooms. Once a distinction is
  # possible, block it for battle rooms
  setTopic: (topic) ->
    db.hset "topic", "main", topic
    @send('topic', topic)  if topic

  has: (id) ->
    @users.contains(id)

  userJSON: ->
    @users.toJSON()
