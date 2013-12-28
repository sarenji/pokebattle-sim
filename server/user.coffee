auth = require('./auth')

class @User
  @get: (args..., next) ->
    user = new User(args...)
    auth.getAuth id, (err, authLevel) ->
      if err then return next(err)
      user.setAuthority(authLevel)
      return next(null, user)

  constructor: (args...) ->
    if args.length == 1
      [ @id ] = args
    else if args.length == 2
      [ @socket, @connections ] = args
    else if args.length == 3
      [ @id, @socket, @connections ] = args

  toJSON: ->
    json = {
      'id': @id
    }
    json['authority'] = @authority  if @authority
    json

  setAuthority: (newAuthority) ->
    @authority = newAuthority
    @send("auth change", @id)

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