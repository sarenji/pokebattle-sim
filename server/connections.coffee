{_} = require 'underscore'
sockjs = require 'sockjs'
{User} = require './user'

# A wrapper for sockjs which manages multiple connections with a higher level of abstraction.
# Todo: Don't use array parameters and use object parameters instead
class @ConnectionServer
  constructor: (httpServer, lobby, options) ->
    @sockjs = sockjs.listen(httpServer, options)
    @lobby = lobby
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
        try
          @trigger(user, data.messageType, data.data...)
        catch e
          console.error(e.stack)
          @lobby.message("<b>A crash occurred!</b> We stopped and logged it, but whatever caused the crash will not work.")

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
        for i in [0...@users.length] by 1
          if @users[i] == user
            @users.splice(i, 1)
            i -= 1
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
