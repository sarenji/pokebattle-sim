sockjs = require 'sockjs'
{User} = require './user'
require 'sugar'

# A wrapper for sockjs which manages multiple connections with a higher level of abstraction.
# Todo: Don't use array parameters and use object parameters instead
class @ConnectionServer
  constructor: (httpServer, options) ->
    @sockjs = sockjs.listen(httpServer, options)
    @users = []
    @callbacks = {}

    @sockjs.on 'connection', (socket) =>
      user = new User(socket, this)

      socket.on 'data', (data) =>
        # todo: error handling.
        data = JSON.parse(data)
        messageType = data.messageType
        for callback in (@callbacks[messageType] || [])
          callback.apply(user, [user, data.data...])

      socket.on 'close', =>
        @users.remove(socket)
        for callback in @callbacks['close']
          callback.call(user, user)
        delete user.connections

      @users.push(user)

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  broadcast: (args...) ->
    user.send(args...)  for user in @users
