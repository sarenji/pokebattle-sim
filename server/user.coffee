class @User
  constructor: (args...) ->
    if args.length == 1
      [ @id ] = args
    else if args.length == 2
      [ @socket, @connections ] = args
    else if args.length == 3
      [ @id, @socket, @connections ] = args

  toJSON: -> {
    'id': @id
  }

  send: (type, data...) ->
    @socket?.write(JSON.stringify(messageType: type, data: data))

  broadcast: (args...) ->
    user.send(args...)  for user in @connections.users when this != user

  error: (args...) ->
    @send("error", args...)

  message: (msg) ->
    @send("raw message", msg)

  close: ->
    @socket?.close()
