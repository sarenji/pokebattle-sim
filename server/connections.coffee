sockjs = require 'sockjs'
{_} = require 'underscore'

# A wrapper around the sockjs socket to support additional operations
class Socket
  constructor: (socket) ->
    @id = _.uniqueId()
    @socket = socket

  send: (type, data...) ->
    @socket.write(JSON.stringify(messageType: type, data: data))

# A wrapper for sockjs which manages multiple connections with a higher level of abstraction.
# Todo: Don't use array parameters and use object parameters instead
class @ConnectionServer
  constructor: (httpServer, options) ->
    @sockjs = sockjs.listen(httpServer, options)
    @sockets = []
    @callbacks = {}

    @sockjs.on 'connection', (socket) =>
      socketWrapper = new Socket(socket)

      socket.on 'data', (data) =>
        # todo: error handling.
        data = JSON.parse(data)
        messageType = data.messageType
        callback.apply(socketWrapper, data.data) for callback in (@callbacks[messageType] || [])

      socket.on 'close', =>
        @sockets.remove(socket)

      @sockets.push(socketWrapper)

  on: (type, callback) ->
    @callbacks[type] ?= []
    @callbacks[type].push(callback)

  addEvents: (events) ->
    @on(type, callback) for type, callback of events

  broadcast: (type, data...) ->
    socket.send(type, data...) for socket in @sockets