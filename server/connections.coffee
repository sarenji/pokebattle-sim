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
        try
          data = JSON.parse(data)
        catch e
          # Invalid JSON. Discard.
          return
        @trigger(user, data.messageType, data.data...)

      # Hack for Heroku:
      # https://github.com/sockjs/sockjs-node/issues/57#issuecomment-5242187
      if process.env.USING_HEROKU
        intervalId = setInterval ->
          try
            socket._session.recv.didClose()
          catch x
        , 15000

      socket.on 'close', =>
        if intervalId then clearTimeout(intervalId)
        @users.remove((u) -> u == user)
        for callback in @callbacks['close']
          callback.call(user, user)
        delete user.connections

      @users.push(user)
      @trigger(user, 'connection')

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  trigger: (user, eventName, args...) ->
    for callback in (@callbacks[eventName] || [])
      callback.apply(user, [user, args...])

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  broadcast: (args...) ->
    user.send(args...)  for user in @users
