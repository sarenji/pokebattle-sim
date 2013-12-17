class @Room
  constructor: (@name) ->
    @users = {}

  # Adds a user to this room.
  # Returns the number of connections that this user has.
  addUser: (user) ->
    array = (@users[user] ||= [])
    array.push(user)  if user not in array
    array.length

  # Removes a user from this room.
  # Returns the number of remaining connections this user has.
  removeUser: (user) ->
    array = @users[user]
    return 0  if !array
    index = array.indexOf(user)
    array.splice(index, 1)  if index != -1
    delete @users[user]  if array.length == 0
    array.length

  userJSON: ->
    Object.keys(@users).map((user) -> {id: user})
