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
    return 0  if !array
    index = array.indexOf(socket)
    return array.length  if index == -1
    array.splice(index, 1)
    length = array.length
    delete @sockets[socket.id]  if length == 0
    return length

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
