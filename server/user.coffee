# A wrapper around the sockjs socket to support additional operations
class @User
  constructor: (@socket, @connections) ->
    # TODO: Hacky solution to help spectators along
    @queue = []

  tell: (args...) ->
    @queue.push(args)

  send: (type, data...) ->
    @socket.write(JSON.stringify(messageType: type, data: data))

  broadcast: (type, data...) ->
    for user in @connections.users
      continue  if user == this
      user.send(type, data...)

  toJSON: -> {
    'id' : @id
  }
