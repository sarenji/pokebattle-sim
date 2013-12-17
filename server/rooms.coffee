class @Room
  constructor: (@name) ->
    @users = {}

  # Adds a user to this room.
  # Returns the number of connections that this user has.
  addUser: (user) ->
    @users[user] ||= 0
    @users[user]  += 1

  # Removes a user from this room.
  # Returns the number of remaining connections this user has.
  removeUser: (user) ->
    count = @users[user]
    return 0  if !count
    @users[user] -= 1
    delete @users[user]  if @users[user] == 0
    @users[user] || 0

  userJSON: ->
    Object.keys(@users).map((user) -> {id: user})
