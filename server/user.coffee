class @User
  constructor: (args...) ->
    if args.length == 1
      [ @id ] = args
      @name = @id
    else if args.length == 2
      [ @socket, @connections ] = args
    else if args.length == 3
      [ @id, @socket, @connections ] = args
      @name = @id
    else if args.length == 4
      [ @id, @socket, @connections, @name ] = args

  toJSON: ->
    json = {
      'id': @id
    }
    json['authority'] = @authority  if @authority
    json

  send: (type, data...) ->
    @socket?.write(JSON.stringify(messageType: type, data: data))

  broadcast: (args...) ->
    user.send(args...)  for user in @connections.users when this != user

  error: (args...) ->
    @send("error", args...)

  message: (msg) ->
    @send("rawMessage", msg)

  close: ->
    @socket?.close()

# A fake user created to mask an alt's identity
class @MaskedUser extends @User
  constructor: (original, altName) ->
    @original = original
    super(original.id, original.socket, original.connections, altName)

  toJSON: ->
    superJson = super()
    superJson.id = @name  # conceal the original id
    superJson