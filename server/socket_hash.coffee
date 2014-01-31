class @SocketHash
  constructor: ->
    @sockets = {}

  add: (socket) ->
    if !@containsSocket(socket)
      @sockets[socket.id] ?= []
      @sockets[socket.id].push(socket)
    @sockets[socket.id].length

  remove: (socket) ->
    array = @sockets[socket.id]
    return false  if !array
    index = array.indexOf(socket)
    return false  if index == -1
    array.splice(index, 1)
    array.length

  contains: (socketId) ->
    @sockets[socketId]?

  containsSocket: (socket) ->
    for id, array of @sockets
      if socket in array
        return true
    return false

  send: (socketId, args...) ->
    for socket in @sockets[socketId] || []
      socket.send(args...)
