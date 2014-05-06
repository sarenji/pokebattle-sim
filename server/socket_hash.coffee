class @SocketHash
  constructor: ->
    @sockets = {}

  add: (socket) ->
    id = socket.id.toLowerCase()
    if !@containsSocket(socket)
      @sockets[id] ?= []
      @sockets[id].push(socket)
    @sockets[id].length

  remove: (socket) ->
    id = socket.id.toLowerCase()
    array = @sockets[id]
    return 0  if !array
    index = array.indexOf(socket)
    return array.length  if index == -1
    array.splice(index, 1)
    length = array.length
    delete @sockets[id]  if length == 0
    return length

  contains: (socketId) ->
    socketId = String(socketId).toLowerCase()
    @sockets[socketId]?

  containsSocket: (socket) ->
    for id, array of @sockets
      if socket in array
        return true
    return false

  broadcast: ->
    for id, sockets of @sockets
      for socket in sockets
        socket.send.apply(socket, arguments)

  send: (socketId, args...) ->
    @iterate socketId, (socket) ->
      socket.send(args...)

  error: (socketId, args...) ->
    @iterate socketId, (socket) ->
      socket.error(args...)

  iterate: (socketId, iter) ->
    socketId = String(socketId).toLowerCase()
    for socket in @get(socketId)
      iter(socket)

  get: (socketId) ->
    socketId = String(socketId).toLowerCase()
    return @sockets[socketId] || []

  values: ->
    sockets = []
    for id, array of @sockets
      sockets.push(array...)
    sockets

  close: (id) ->
    id = String(id).toLowerCase()
    for socket in @get(id)
      socket.close()
    delete @sockets[id]
    return 0

  toJSON: ->
    for socketId, sockets of @sockets
      sockets[0].toJSON()
