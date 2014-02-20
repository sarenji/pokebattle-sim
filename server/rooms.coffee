{User} = require('./user')
{SocketHash} = require('./socket_hash')
db = require('./database')
auth = require('./auth')
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
    @send('update chat', user.id, message)

  message: (message) ->
    @send('raw message', message)

  send: ->
    @users.broadcast.apply(@users, arguments)

  setAuthority: (user, newAuthority) ->
    if user instanceof User
      user.authority = newAuthority
    else
      for user in @users.get(user)
        user.authority = newAuthority

  # Set the room's topic. Does not work for battle rooms.
  # TODO: Or rather, it shouldn't work for battle rooms. Once a distinction is
  # possible, block it for battle rooms
  setTopic: (topic) ->
    db.hset "topic", "main", topic
    @send('topic', topic)  if topic

  has: (id) ->
    @users.contains(id)

  # A length of -1 denotes a permanent ban.
  ban: (username, reason, length = -1) ->
    auth.ban(username, reason, length)
    @users.error(username, errors.BANNED, reason, length)
    @users.close(username)

  unban: (username, next) ->
    auth.unban(username, next)

  userJSON: ->
    @users.toJSON()
